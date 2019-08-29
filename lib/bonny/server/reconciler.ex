defmodule Bonny.Server.Reconciler do
  @moduledoc """
  Continuously reconciles a set of kubernetes resources.

  `reconcile/1` will be executed asynchronously with each result returned from `reconcilable_resources/0`.

  `reconcilable_resources/0` has a default implementation of running `K8s.Client.stream/2` with `reconcile_operation/0`.

  For a working example of the `Reconciler see `Bonny.Server.Scheduler`

  ## Examples
    Print every pod. Not very useful, but a simple copy-paste example.

      defmodule PodPrinterReconciler do
        use Bonny.Server.Reconciler, frequency: 15

        @impl true
        def reconcile(pod) do
          IO.inspect(pod)
          :ok
        end

        @impl true
        def reconcile_operation(), do: K8s.Client.list("v1", :pods, namespace: "default")

        @impl true
        def reconcilable_resources() do
          operation = reconcile_operation()
          cluster = Bonny.Config.cluster_name()
          K8s.Client.stream(operation, cluster)
        end
      end

      PodPrinterReconciler.start_link()

    A quick and dirty chaos monkey for pods. 20% chance of eviction every 15 seconds.

      defmodule ChaosMonkeyReconciler do
        use Bonny.Server.Reconciler, frequency: 15
        @percent_chance_evicted 20

        @impl true
        def reconcile(pod) do
          chance = :rand.uniform(100)

          if chance < @percent_chance_evicted do
            my_function_to_evict_pod(pod)
          end
          :ok
        end

        @impl true
        def reconcile_operation(), do: K8s.Client.list("v1", :pods, namespace: :all)

        @impl true
        def reconcilable_resources() do
          operation = reconcile_operation()
          cluster = Bonny.Config.cluster_name()
          K8s.Client.stream(operation, cluster)
        end
      end

      ChaosMonkeyReconciler.start_link()

    Reconcile a CRD's resources every 15 seconds

      defmodule MyCustomResourceReconciler do
        use Bonny.Server.Reconciler, frequency: 15

        @impl true
        def reconcile(resource) do
          # You should do something much cooler than inspect here...
          IO.inspect(resource)
          :ok
        end

        @impl true
        def reconcile_operation() do
          K8s.Client.list("example.com/v1", "MyCustomResourceDef", namespace: :all)
        end

        @impl true
        def reconcilable_resources() do
          operation = reconcile_operation()
          cluster = Bonny.Config.cluster_name()
          K8s.Client.stream(operation, cluster)
        end
      end

      MyCustomResourceReconciler.start_link()
  """

  @doc """
  Reconciles a resource. This will receive a list of resources from `reconcilable_resources/0`.
  """
  @callback reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}

  @doc """
  [`K8s.Operation`](https://hexdocs.pm/k8s/K8s.Operation.html) to reconcile.

  ## Examples
  ```elixir
    def reconcile_operation() do
      K8s.Client.list("v1", :pods, namespace: :all)
    end
  ```
  """
  @callback reconcile_operation() :: K8s.Operation.t()

  @doc """
  (Optional) List of resources to be reconciled.

  Default implementation is to stream all resources (`reconcile_operation/0`) from the cluster (`Bonny.Config.cluster_name/0`).
  """
  @callback reconcilable_resources() :: {:ok, list(map())} | {:error, any()}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bonny.Server.Reconciler
      use GenServer
      @frequency (opts[:frequency] || 30) * 1000
      @initial_delay opts[:initial_delay] || 500
      @client opts[:client] || K8s.Client

      def start_link(), do: start_link(%{})
      def start_link(state), do: GenServer.start_link(__MODULE__, state)
      def client(), do: @client

      @impl GenServer
      def init(state) do
        Bonny.Sys.Event.reconciler_initialized(%{}, %{module: __MODULE__})
        Bonny.Server.Reconciler.schedule(self(), @initial_delay)
        {:ok, state}
      end

      @impl GenServer
      def handle_info(:run, state) do
        Bonny.Server.Reconciler.run(__MODULE__)
        Bonny.Server.Reconciler.schedule(self(), @frequency)
        {:noreply, state}
      end

      @impl GenServer
      def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
        Bonny.Sys.Event.reconciler_genserver_down(%{}, %{module: __MODULE__})
        {:stop, :normal, state}
      end

      @impl GenServer
      def handle_info(_other, state) do
        {:noreply, state}
      end

      @impl Bonny.Server.Reconciler
      def reconcilable_resources() do
        operation = reconcile_operation()
        cluster = Bonny.Config.cluster_name()
        @client.stream(operation, cluster)
      end

      defoverridable reconcilable_resources: 0
    end
  end

  @doc """
  Schedules a run of a started `Reconciler`
  """
  @spec schedule(pid(), pos_integer()) :: reference()
  def schedule(pid, frequency) do
    Process.send_after(pid, :run, frequency)
  end

  @doc """
  Runs a `Reconcilers` `reconcile/1` for each resource return by `reconcilable_resources/0`
  """
  @spec run(module) :: no_return
  def run(module) do
    metadata = %{module: module}
    Bonny.Sys.Event.reconciler_run_started(%{}, metadata)

    {measurements, result} = Bonny.Sys.Event.measure(module, :reconcilable_resources, [])

    case result do
      {:ok, resources} ->
        Bonny.Sys.Event.reconciler_fetch_succeeded(measurements, metadata)
        Enum.each(resources, &reconcile_async(&1, module))

      {:error, error} ->
        metadata = Map.put(metadata, :error, error)
        Bonny.Sys.Event.reconciler_fetch_failed(measurements, metadata)
    end

    nil
  end

  @spec reconcile_async(map, module) :: no_return
  defp reconcile_async(resource, module) do
    Task.start(fn ->
      {measurements, result} = Bonny.Sys.Event.measure(module, :reconcile, [resource])

      metadata = %{
        module: module,
        name: K8s.Resource.name(resource),
        namespace: K8s.Resource.namespace(resource),
        kind: K8s.Resource.kind(resource),
        api_version: resource["apiVersion"]
      }

      case result do
        :ok ->
          Bonny.Sys.Event.reconciler_reconcile_succeeded(measurements, metadata)

        {:ok, _} ->
          Bonny.Sys.Event.reconciler_reconcile_succeeded(measurements, metadata)

        {:error, error} ->
          metadata = Map.put(metadata, :error, error)
          Bonny.Sys.Event.reconciler_reconcile_failed(measurements, metadata)
      end
    end)
  end
end
