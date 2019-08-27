defmodule Bonny.Server.Reconciler do
  @moduledoc """
  Continuously reconciles a set of kubernetes resources.

  `reconcile/1` will be execute asynchronously with each result returned from `reconcile_resources/0`.

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
        def reconcile_resources() do
          operation = K8s.Client.list("v1", :pods, namespace: "default")
          cluster = Bonny.Config.cluster_name()

          with {:ok, stream} <- K8s.Client.stream(operation, cluster) do
            records = Enum.into(stream, [])
            {:ok, records}
          end
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
        def reconcile_resources() do
          operation = K8s.Client.list("v1", :pods, namespace: :all)
          cluster = Bonny.Config.cluster_name()

          with {:ok, stream} <- K8s.Client.stream(operation, cluster) do
            records = Enum.into(stream, [])
            {:ok, records}
          end
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
        def reconcile_resources() do
          operation = K8s.Client.list("example.com/v1", "MyCRDName", namespace: :all)
          cluster = Bonny.Config.cluster_name()
          Bonny.Server.Reconciler.stream_resources(operation, cluster)
        end
      end

      MyCustomResourceReconciler.start_link()
  """

  @doc """
  Reconciles a resource.

  ## Examples
  ```elixir
    def reconcile(resource) do
      # You should do something much cooler than inspect here...
      IO.inspect(resource)
      :ok
    end
  ```
  """
  @callback reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}

  @doc """
  List of resources to be reconciled.

  ## Examples
  ```elixir
    def reconcile_resources() do
      operation = K8s.Client.list("v1", :pods, namespace: :all)
      cluster = Bonny.Config.cluster_name()
      Bonny.Server.Reconciler.stream_resources(operation, cluster)
    end
  ```
  """
  @callback reconcile_resources() :: {:ok, list(map())} | {:error, any()}

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
  Runs a `Reconcilers` `reconcile/1` for each resource return by `reconcile_resources/0`
  """
  @spec run(module) :: no_return
  def run(module) do
    metadata = %{module: module}
    Bonny.Sys.Event.reconciler_run_started(%{}, metadata)

    {measurements, result} = Bonny.Sys.Event.measure(module, :reconcile_resources, [])

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

  @doc "Stream a `K8s.Operation` into an `Enum`."
  @spec stream_resources(K8s.Operation.t(), atom()) :: {:ok, list(map())} | {:error, any()}
  def stream_resources(operation, cluster) do
    with {:ok, stream} <- K8s.Client.stream(operation, cluster) do
      records = Enum.into(stream, [])
      {:ok, records}
    end
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
