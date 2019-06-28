defmodule Bonny.Server.Reconciler do
  @moduledoc """
  Continuously reconciles the results of a `K8s.Client.list/3` `K8s.Operation`.

  `reconcile/1` will be execute asynchronously with each result returned from `resources/0`.

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
        def resources() do
          operation = K8s.Client.list("v1", :pods, namespace: "default")
          K8s.Client.stream(operation, :default)
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
        def resources() do
          operation = K8s.Client.list("v1", :pods, namespace: :all)
          K8s.Client.stream(operation, :default)
        end
      end

      ChaosMonkeyReconciler.start_link()

    Reconcile a CRD's resources every 15 seconds

      defmodule MyCustomResourceReconciler do
        use Bonny.Server.Reconciler, frequency: 15

        @impl true
        def reconcile(resource) do
          IO.inspect(resource)
          :ok
        end

        @impl true
        def resources() do
          operation = K8s.Client.list("example.com/v1", "MyCustomResourceDefName", namespace: :all)
          K8s.Client.stream(operation, :default)
        end
      end

      MyCustomResourceReconciler.start_link()
  """

  @doc """
  Reconciles a resource.
  """
  @callback reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}

  @doc """
  Gets a list of resources to reconcile.
  """
  @callback resources() :: {:ok, Enumerable.t()} | {:error, any()}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bonny.Server.Reconciler
      use GenServer
      @frequency (opts[:frequency] || 30) * 1000

      def start_link(), do: start_link(%{})
      def start_link(state), do: GenServer.start_link(__MODULE__, state)

      @impl GenServer
      def init(state) do
        Bonny.Sys.Event.reconciler_initialized(%{}, %{module: __MODULE__})
        Bonny.Server.Reconciler.schedule(self(), 500)
        {:ok, state}
      end

      @impl GenServer
      def handle_info(:run, state) do
        Bonny.Server.Reconciler.run(__MODULE__)
        Bonny.Server.Reconciler.schedule(self(), @frequency)
        {:noreply, state}
      end
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
  Runs a `Reconcilers` `reconcile/1` for each resource return by `resources/0`
  """
  @spec run(module) :: no_return
  def run(module) do
    metadata = %{module: module}
    Bonny.Sys.Event.reconciler_run_started(%{}, metadata)

    {measurements, result} = Bonny.Sys.Event.measure(module, :resources, [])

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
          Bonny.Sys.Event.reconciler_run_succeeded(measurements, metadata)

        {:ok, _} ->
          Bonny.Sys.Event.reconciler_run_succeeded(measurements, metadata)

        {:error, error} ->
          metadata = Map.put(metadata, :error, error)
          Bonny.Sys.Event.reconciler_run_failed(measurements, metadata)
      end
    end)
  end
end
