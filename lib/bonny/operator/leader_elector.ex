defmodule Bonny.Operator.LeaderElector do
  @moduledoc """
  The leader uses a [Kubernetes
  Lease](https://kubernetes.io/docs/concepts/architecture/leases/) to make sure
  the operator only runs on one single replica (the leader) at the same time.

  ## Enabling the Leader Election

  > #### Functionality still in Beta {: .warning}
  >
  > The leader election is still being tested. Enable it for testing purposes
  > only and please report any issues on Github.

  To enable leader election you have to pass the `enable_leader_election: true` option when [adding the operator to your Supervisor](#adding-the-operator-to-your-supervisor):

  ```elixir
  defmodule MyOperator.Application do
    use Application

    def start(_type, env: env) do
      children = [
        {MyOperator.Operator,
        conn: MyOperator.K8sConn.get!(env),
        watch_namespace: :all,
        enable_leader_election: true} # <-- starts the leader elector
      ]

      opts = [strategy: :one_for_one, name: MyOperator.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```
  """

  use GenServer

  import YamlElixir.Sigil

  require Logger

  # lease_duration is the duration that non-leader candidates will
  # wait to force acquire leadership. This is measured against time of
  # last observed ack.
  @lease_duration 15

  # renew_deadline is the duration that the acting master will retry
  # refreshing leadership before giving up.
  @renew_deadline 10

  # retry_period is the duration the LeaderElector clients should wait
  # between tries of actions.
  @retry_period 2

  defstruct [:controllers, :operator, :init_args, :conn, operator_pid: nil]

  @spec start_link(controllers :: list(), operator :: atom(), init_args :: Keyword.t()) ::
          {:ok, pid}
  def start_link(controllers, operator, init_args) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {controllers, operator, init_args})
    send(pid, :maybe_acquire_leadership)
    {:ok, pid}
  end

  @impl true
  def init({controllers, operator, init_args}) do
    conn = Keyword.fetch!(init_args, :conn)

    {:ok,
     struct!(__MODULE__,
       controllers: controllers,
       operator: operator,
       conn: conn,
       init_args: init_args
     )}
  end

  @impl true
  def handle_info(:maybe_acquire_leadership, state) do
    am_i_leader? = not is_nil(state.operator_pid)
    Logger.debug("Starting leadership evaluation", library: :bonny)

    state =
      case acquire_or_renew(state.conn, state.operator) do
        :ok when am_i_leader? ->
          Logger.debug("I am the leader - I stay the leader.", library: :bonny)
          state

        :ok ->
          Logger.debug("I am the new leader. Starting the operator.", library: :bonny)

          {:ok, pid} =
            Bonny.Operator.Supervisor.start_link(
              state.controllers,
              state.operator,
              state.init_args
            )

          ref = Process.monitor(pid)
          struct!(state, operator_pid: {pid, ref})

        _other when am_i_leader? ->
          Logger.debug(
            "I was the leader but somebody else took over leadership. Terminating operator.",
            library: :bonny
          )

          {pid, _ref} = state.operator_pid
          Process.exit(pid, :shutdown)
          struct!(state, operator_pid: nil)

        _other ->
          Logger.debug("Somebody else is the leader.", library: :bonny)
          state
      end

    timeout = if is_nil(state.operator_pid), do: @retry_period, else: @renew_deadline
    Process.send_after(self(), :maybe_acquire_leadership, timeout * 1000)
    {:noreply, state}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, _reason},
        %__MODULE__{operator_pid: {pid, ref}} = state
      ) do
    Logger.warn(
      "Uh-oh! Our operator just went down. Guess that means I have to give up leadership. Boohoo!",
      library: :bonny
    )

    release(state.conn, state.operator)
    struct!(state, operator_pid: nil)
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    Logger.warn(
      "Very starnge. A process I'm monitoring went down. But I'm not the leader. Looks like a bug in Bonny. Anyway, releaseing the lock if I have it.",
      library: :bonny
    )

    release(state.conn, state.operator)
    struct!(state, operator_pid: nil)
  end

  @impl true
  def terminate(_, %__MODULE__{operator_pid: {pid, _ref}} = state) do
    Logger.debug("I'm going down - releasing the lock now.", library: :bonny)
    release(state.conn, state.operator)
    Process.exit(pid, :shutdown)
    struct!(state, operator_pid: nil)
  end

  def terminate(_, state) do
    Logger.debug("I'm going down but I'm not the leader so chill!")
    state
  end

  defp release(conn, operator) do
    my_name = Bonny.Config.instance_name()

    case get_lease(conn, operator) do
      {:error, _} ->
        :ok

      {:ok, %{"spec" => %{"holderIdentity" => ^my_name}} = old_lease} ->
        old_lease
        |> put_in(~w(spec leaseDurationSeconds), 1)
        |> Bonny.Resource.apply(conn, [])

        :ok

      _ ->
        :ok
    end
  end

  defp acquire_or_renew(conn, operator) do
    now = DateTime.utc_now()
    my_lease = lease(now, @lease_duration, operator)

    case get_lease(conn, operator) do
      {:error, %K8s.Client.APIError{reason: "NotFound"}} ->
        Logger.debug("Lease not found. Trying to create it.", library: :bonny)

        result =
          K8s.Client.create(my_lease)
          |> K8s.Client.put_conn(conn)
          |> K8s.Client.run()

        case result do
          {:ok, _} ->
            Logger.debug("Lease successfully created.", library: :bonny)
            :ok

          {:error, %K8s.Client.APIError{reason: "AlreadyExists"}} ->
            Logger.debug(
              "Failed creating lease. Seems to have been created by somebody else in the meantime.",
              library: :bonny
            )

            :locked
        end

      {:ok, old_lease} ->
        if locked_by_sbdy_else?(now, old_lease, my_lease) do
          Logger.debug(
            ~s(Lock is held by "#{old_lease["spec"]["holderIdentity"]}" and has not yet expired.),
            library: :bonny
          )

          :locked
        else
          my_lease =
            if old_lease["spec"]["holderIdentity"] == my_lease["spec"]["holderIdentity"] do
              Logger.debug("I'm holding the lock. Trying to renew it", library: :bonny)

              my_lease
              |> put_in(~w(spec acquireTime), old_lease["spec"]["acquireTime"])
              |> put_in(~w(metadata resourceVersion), old_lease["metadata"]["resourceVersion"])
            else
              Logger.debug(
                ~s(Lock is held by "#{old_lease["spec"]["holderIdentity"]}" but has expired. Trying to acquire it.),
                library: :bonny
              )

              my_lease
              |> put_in(~w(metadata resourceVersion), old_lease["metadata"]["resourceVersion"])
            end

          case Bonny.Resource.apply(my_lease, conn, []) do
            {:ok, _} ->
              Logger.debug(~s(Lock successfully acquired/renewed.), library: :bonny)

              :ok

            {:error, exception} when is_exception(exception) ->
              Logger.debug(~s(Failed aquiring/renewing the lock. #{Exception.message(exception)}),
                library: :bonny
              )

              :error
          end
        end
    end
  end

  defp locked_by_sbdy_else?(now, %{"spec" => old_lease_spec}, my_lease) do
    {:ok, last_renew, 0} = DateTime.from_iso8601(old_lease_spec["renewTime"])
    time_of_expiration = DateTime.add(last_renew, old_lease_spec["leaseDurationSeconds"])

    String.length(old_lease_spec["holderIdentity"]) > 0 and
      old_lease_spec["holderIdentity"] != my_lease["spec"]["holderIdentity"] and
      DateTime.compare(time_of_expiration, now) == :gt
  end

  defp lease_name(operator) do
    operator_hash =
      :crypto.hash(:md5, Atom.to_string(operator)) |> Base.encode16() |> String.downcase()

    "#{Bonny.Config.namespace()}-#{Bonny.Config.name()}-#{operator_hash}"
  end

  defp get_lease(conn, operator) do
    K8s.Client.get("coordination.k8s.io/v1", "Lease",
      name: lease_name(operator),
      namespace: Bonny.Config.namespace()
    )
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()
  end

  defp lease(now, lease_duration, operator) do
    ~y"""
    apiVersion: coordination.k8s.io/v1
    kind: Lease
    metadata:
      name: #{lease_name(operator)}
      namespace: #{Bonny.Config.namespace()}
    spec:
      holderIdentity: #{Bonny.Config.instance_name()}
      leaseDurationSeconds: #{lease_duration}
      renewTime: #{DateTime.to_iso8601(now)}
      acquireTime: #{DateTime.to_iso8601(now)}
    """
  end
end
