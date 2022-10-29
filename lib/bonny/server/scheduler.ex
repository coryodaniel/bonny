defmodule Bonny.Server.Scheduler do
  @moduledoc """
  Kubernetes custom scheduler interface. Built on top of `Reconciler`.

  The only function that needs to be implemented is `select_node_for_pod/2`. All others defined by behaviour have default implementations.

  ## Examples
    Will schedule each unschedule pod with `spec.schedulerName=cheap-node` to a node with a label `cheap=true`.
    `nodes` is a stream that can be lazily filtered:

      defmodule CheapNodeScheduler do
        use Bonny.Server.Scheduler, name: "cheap-node"

        @impl Bonny.Server.Scheduler
        def select_node_for_pod(_pod, nodes) do
          nodes
          |> Stream.filter(fn(node) ->
            is_cheap = K8s.Resource.label(node, "cheap")
            is_cheap == "true"
          end)
          |> Enum.take(1)
          |> List.first
        end
      end

      CheapNodeScheduler.start_link()

    Will schedule each unschedule pod with `spec.schedulerName=random-node` to a random node:

      defmodule RandomNodeScheduler do
        use Bonny.Server.Scheduler, name: "random-node"

        @impl Bonny.Server.Scheduler
        def select_node_for_pod(_pod, nodes) do
          Enum.random(nodes)
        end
      end

      RandomNodeScheduler.start_link()

    Override `nodes/0` default implementation (`pods/0` can be overridden too).
    Schedules pod on a random GPU node:

      defmodule GpuScheduler do
        use Bonny.Server.Scheduler, name: "gpu-node"

        @impl Bonny.Server.Scheduler
        def select_node_for_pod(_pod, nodes) do
          Enum.random(nodes)
        end

        @impl Bonny.Server.Scheduler
        def nodes() do
          label = "my.label.on.gpu.instances"
          conn = Bonny.Config.conn()

          op = K8s.Client.list("v1", :nodes)
          K8s.Client.stream(conn, op, params: %{labelSelector: label})
        end
      end

      GpuScheduler.start_link()
  """

  require Logger

  @doc """
  Name of the scheduler.
  """
  @callback name() :: binary()

  @doc """
  List of nodes available to this scheduler.

  Default implementation is all nodes in cluster.
  """
  @callback nodes(K8s.Conn.t()) :: {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  Field selector for selecting unscheduled pods waiting to be scheduled by this scheduler.

  Default implementation is all unscheduled pods assigned to this scheduler.
  """
  @callback field_selector() :: binary()

  @callback conn() :: K8s.Conn.t()

  @doc """
  Selects the best node for the current `pod`.

  Takes the current unscheduled pod and a `Stream` of nodes. `pod` is provided in the event that `taints` or `affinities` would need to be respected by the scheduler.

  Returns the node to schedule on.
  """
  @callback select_node_for_pod(map, list(map)) :: map

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bonny.Server.Scheduler
      @behaviour Bonny.Server.Reconciler

      @name opts[:name] || Macro.to_string(__MODULE__)

      @doc "Scheduler name"
      @impl Bonny.Server.Scheduler
      def name(), do: @name

      @doc "Kubernetes HTTP API `fieldSelector`."
      @impl Bonny.Server.Scheduler
      def field_selector(), do: Bonny.Server.Scheduler.field_selector(@name)

      @doc "List of nodes available to this scheduler."
      @impl Bonny.Server.Scheduler
      def nodes(conn), do: Bonny.Server.Scheduler.nodes(conn)

      @spec child_spec(keyword()) :: Supervisor.child_spec()
      def child_spec(args \\ []) do
        list_operation =
          K8s.Client.list("v1", :pods, namespace: :all)
          |> Map.put(:query_params, fieldSelector: field_selector())

        conn = conn()

        args
        |> Keyword.put(
          :stream,
          Bonny.Server.Reconciler.get_stream(__MODULE__, conn, list_operation)
        )
        |> Keyword.put(:termination_delay, 5_000)
        |> Bonny.Server.AsyncStreamRunner.child_spec()
      end

      defdelegate conn(), to: Bonny.Config

      defoverridable nodes: 1, field_selector: 0, conn: 0

      @impl Bonny.Server.Reconciler
      def reconcile(pod), do: Bonny.Server.Scheduler.reconcile(__MODULE__, pod)
    end
  end

  @spec reconcile(module(), map()) :: :ok
  def reconcile(scheduler, pod) do
    conn = scheduler.conn()

    with {:ok, nodes} <- nodes(conn),
         node <- scheduler.select_node_for_pod(pod, nodes),
         {:ok, _} <- Bonny.Server.Scheduler.bind(scheduler.conn(), pod, node) do
      :ok
    end
  end

  @doc "Kubernetes API `fieldSelector` value for unbound pods waiting on the given scheduler."
  @spec field_selector(binary) :: binary
  def field_selector(scheduler_name) do
    "spec.schedulerName=#{scheduler_name},spec.nodeName="
  end

  @doc "Binds a pod to a node"
  @spec bind(K8s.Conn.t(), map(), map()) :: {:ok, map} | {:error, atom}
  def bind(conn, pod, node) do
    pod =
      pod
      |> Map.put("apiVersion", "v1")
      |> Map.put("kind", "pod")

    Bonny.Server.Scheduler.Binding.create(conn, pod, node)
  end

  @doc "Returns a list of all nodes in the cluster."
  @spec nodes(K8s.Conn.t()) :: {:ok, list(map())} | {:error, any()}
  def nodes(conn) do
    op = K8s.Client.list("v1", :nodes)

    response = K8s.Client.stream(conn, op)
    metadata = %{operation: op, library: :bonny}

    case response do
      {:ok, stream} ->
        Logger.debug("Scheduler fetching nodes succeeded", metadata)
        {:ok, Enum.into(stream, [])}

      {:error, error} ->
        Logger.error("Scheduler fetching nodes failed", Map.put(metadata, :error, error))
        {:error, error}
    end
  end
end
