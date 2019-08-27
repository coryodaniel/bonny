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
          cluster = Bonny.Config.cluster_name()

          op = K8s.Client.list("v1", :nodes)
          K8s.Client.stream(op, cluster, params: %{labelSelector: label})
        end
      end

      GpuScheduler.start_link()
  """

  @doc """
  Name of the scheduler.
  """
  @callback name() :: binary()

  @doc """
  List of unscheduled pods awaiting this scheduler.

  Default implementation is all unscheduled pods specifying this scheduler in `spec.schedulerName`.
  """
  @callback pods() :: {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  List of nodes available to this scheduler.

  Default implementation is all nodes in cluster.
  """
  @callback nodes() :: {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  Field selector for selecting unscheduled pods waiting to be scheduled by this scheduler.

  Default implementation is all unscheduled pods assigned to this scheduler.
  """
  @callback field_selector() :: binary()

  @doc """
  Selects the best node for the current `pod`.

  Takes the current unscheduled pod and a `Stream` of nodes. `pod` is provided in the event that `taints` or `affinities` would need to be respected by the scheduler.

  Returns the node to schedule on.
  """
  @callback select_node_for_pod(map, list(map)) :: map

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bonny.Server.Scheduler
      use Bonny.Server.Reconciler, frequency: 5
      @name opts[:name] || Macro.to_string(__MODULE__)

      @doc "Scheduler name"
      @impl Bonny.Server.Scheduler
      def name(), do: @name

      @doc "Kubernetes HTTP API `fieldSelector`."
      @impl Bonny.Server.Scheduler
      def field_selector(), do: Bonny.Server.Scheduler.field_selector(@name)

      @doc "List of unscheduled pods awaiting this scheduler."
      @impl Bonny.Server.Scheduler
      def pods(), do: Bonny.Server.Scheduler.pods(__MODULE__)

      @doc "List of nodes available to this scheduler."
      @impl Bonny.Server.Scheduler
      def nodes(), do: Bonny.Server.Scheduler.nodes()

      @impl Bonny.Server.Reconciler
      def reconcile_operation() do
        K8s.Client.list("v1", :pods, namespace: :all)
      end

      @impl Bonny.Server.Reconciler
      defdelegate reconcile_resources(), to: __MODULE__, as: :pods

      defoverridable pods: 0, nodes: 0, field_selector: 0, reconcile_resources: 0

      @impl Bonny.Server.Reconciler
      def reconcile(pod) do
        with {:ok, nodes} <- nodes(),
             node <- select_node_for_pod(pod, nodes),
             {:ok, _} <- Bonny.Server.Scheduler.bind(pod, node) do
          :ok
        end
      end
    end
  end

  @doc "Kubernetes API `fieldSelector` value for unbound pods waiting on the given scheduler."
  @spec field_selector(binary) :: binary
  def field_selector(scheduler_name) do
    "spec.schedulerName=#{scheduler_name},spec.nodeName="
  end

  @doc "Binds a pod to a node"
  @spec bind(map(), map()) :: {:ok, map} | {:error, atom}
  def bind(pod, node) do
    cluster = Bonny.Config.cluster_name()

    pod
    |> Bonny.Server.Scheduler.Binding.new(node)
    |> Bonny.Server.Scheduler.Binding.create(cluster)
  end

  @doc "Returns a list of pods for the given `field_selector`."
  @spec pods(module()) :: {:ok, list(map())} | {:error, any()}
  def pods(module) do
    cluster = Bonny.Config.cluster_name()
    op = module.reconcile_operation()

    response = K8s.Client.stream(op, cluster, params: %{fieldSelector: module.field_selector()})
    metadata = %{module: module, name: module.name()}

    case response do
      {:ok, stream} ->
        Bonny.Sys.Event.scheduler_pods_fetch_succeeded(%{}, metadata)
        pods = Enum.into(stream, [])
        {:ok, pods}

      {:error, error} ->
        Bonny.Sys.Event.scheduler_pods_fetch_failed(%{}, metadata)
        {:error, error}
    end
  end

  @doc "Returns a list of all nodes in the cluster."
  @spec nodes() :: {:ok, list(map())} | {:error, any()}
  def nodes() do
    cluster = Bonny.Config.cluster_name()
    op = K8s.Client.list("v1", :nodes)

    response = K8s.Client.stream(op, cluster)
    measurements = %{}
    metadata = %{}

    case response do
      {:ok, stream} ->
        Bonny.Sys.Event.scheduler_nodes_fetch_succeeded(measurements, metadata)
        nodes = Enum.into(stream, [])
        {:ok, nodes}

      {:error, error} ->
        Bonny.Sys.Event.scheduler_nodes_fetch_failed(measurements, metadata)
        {:error, error}
    end
  end
end
