defmodule Bonny.ControllerV2 do
  @moduledoc ~S"""
  Controllers handle action events observed by a resource watch query.
  Controllers must be registered at the operator together with the resource
  watch query. The operator will then delegate events observed by that query for
  processing to this controller

  Controllers use the `Pluggable.StepBuilder` to build a step in the processing
  pipeline. In order to use it, a step has to be defined and implemented in the
  controller. The step must have the following spec

      step_name(Bonny.Axn.t(), keyword()) :: Bonny.Axn.t()

  The modules `Bonny.Axn` module is imported to your controller. In your event
  handler step you should use the functions `Bonny.Axn.register_descendant/3`,
  `Bonny.Axn.update_status/2` and the ones to  register events:
  `Bonny.Axn.success_event/2`, `Bonny.Axn.failure_event/2` and/or
  `Bonny.Axn.register_event/6`. Note that these functions raise
  exceptions if those resources have already been applied to the cluster.

  ## Example

  Match against the struct's `:action` field which is one of `:add`, `:modify`,
  `:reconcile` or `:delete` to provide an implementation for each case.

      defmodule MyOperator.Controller.CronTabController do

        # other steps
        step :handle_event
        # other steps

        # apply the resource
        def handle_event(%Bonny.Axn{action: action, resource: resource} = axn, _opts)
            when action in [:add, :modify, :reconcile] do
          success_event(axn)
        end

        def handle_event(%Bonny.Axn{action: :delete, resource: resource} = axn, _opts) do
          #
          axn
        end
      end

  Registering your descendants with the `%Bonny.Axn{}` token makes your
  controller easier to test. Be sure to add `Bonny.Pluggable.ApplyDescendants`
  as step to your operator in order for the descendants to be applied to the
  cluster.

      defmodule MyOperator.Controller.CronTabController do

        # other steps
        step :handle_event
        # other steps

        # apply the resource
        def handle_event(axn, _opts) do
          deployment = generate_deployment(axn.resource)

          axn
          |> register_descendant(deployment)
          |> success_event()
        end
      end

  Use `Bonny.Axn.update_status/2` to store API responses or other status data in the
  resource status. Be sure to enable the status subresource in your CRD version
  module.

      defmodule MyOperator.Controller.CronTabController do

        # other steps
        step :handle_event
        # other steps

        # apply the resource
        def handle_event(axn, _opts) do
          response = apply_state(axn.resource)

          axn
          |> update_status(fn status ->
            Map.put(status, "response", response)
          end)
          |> success_event()
        end
      end
  """

  use Supervisor

  @type api :: binary()
  @type resource :: binary()
  @type verb :: binary()
  @type rbac_rule :: %{apiGroups: list(api()), resources: list(resource()), verbs: list(verb())}

  @callback rbac_rules() :: list(rbac_rule)

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Pluggable.StepBuilder

      import Bonny.Axn

      import Bonny.ControllerV2, only: [to_rbac_rule: 1]
      @behaviour Bonny.ControllerV2

      def rbac_rules(), do: []

      defoverridable rbac_rules: 0
    end
  end

  @spec to_rbac_rule({api | list(api), resource | list(resource), verb | list(verb)}) :: rbac_rule
  def to_rbac_rule({api, resources, verbs}) do
    %{
      apiGroups: List.wrap(api),
      resources: List.wrap(resources),
      verbs: List.wrap(verbs)
    }
  end

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args)
  end

  @impl true
  def init(init_args) do
    query = Keyword.fetch!(init_args, :query)
    controller = Keyword.fetch!(init_args, :controller)
    operator = Keyword.fetch!(init_args, :operator)
    conn = Keyword.get_lazy(init_args, :conn, fn -> Bonny.Config.conn() end)

    watcher_stream =
      Bonny.Server.Watcher.get_raw_stream(conn, ensure_watch_query(query))
      |> Stream.map(&Bonny.Operator.run(&1, controller, operator, conn))

    reconciler_stream =
      conn
      |> Bonny.Server.Reconciler.get_raw_stream(ensure_list_query(query))
      |> Task.async_stream(&Bonny.Operator.run({:reconcile, &1}, controller, operator, conn))

    children = [
      {Bonny.Server.AsyncStreamRunner, id: Watcher, stream: watcher_stream},
      {Bonny.Server.AsyncStreamRunner,
       id: Reconciler, stream: reconciler_stream, termination_delay: 30_000}
    ]

    Supervisor.init(
      children,
      strategy: :one_for_one,
      max_restarts: 20,
      max_seconds: 120
    )
  end

  defp ensure_list_query(%K8s.Operation{verb: :watch} = op) do
    struct!(op, verb: :list)
  end

  defp ensure_list_query(%K8s.Operation{verb: :watch_all_namespaces} = op) do
    struct!(op, verb: :list_all_namespaces)
  end

  defp ensure_list_query(op), do: op

  defp ensure_watch_query(%K8s.Operation{verb: :list} = op) do
    struct!(op, verb: :watch)
  end

  defp ensure_watch_query(%K8s.Operation{verb: :list_all_namespaces} = op) do
    struct!(op, verb: :watch_all_namespaces)
  end

  defp ensure_watch_query(op), do: op
end
