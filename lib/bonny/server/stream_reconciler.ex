defmodule Bonny.Server.StreamReconciler do
  use Task
  require Logger

  @default_interval 30 * 1000

  def start_link(args) do
    name = Keyword.get(args, :name)
    reconcile_callback = Keyword.fetch!(args, :reconcile)
    resource_stream = Keyword.fetch!(args, :resource_stream)
    interval = Keyword.get(args, :interval, @default_interval)

    {:ok, pid} =
      Task.start_link(__MODULE__, :run, [resource_stream, reconcile_callback, interval])

    if !is_nil(name), do: Process.register(pid, name)

    {:ok, pid}
  end

  def run(resource_stream, reconcile_callback, interval) do
    reconcile_all(resource_stream, reconcile_callback)
    Process.sleep(interval)
    run(resource_stream, reconcile_callback, interval)
  end

  defp reconcile_all(resource_stream, reconcile_callback) do
    resource_stream
    |> Flow.from_enumerable()
    |> Flow.map(fn
      resource when is_map(resource) ->
        reconcile_single_resource(resource, reconcile_callback)

      {:error, error} ->
        Logger.error(error)
    end)
    |> Stream.run()
  end

  defp reconcile_single_resource(resource, reconcile_callback) do
    metadata = %{
      name: K8s.Resource.name(resource),
      namespace: K8s.Resource.namespace(resource),
      kind: K8s.Resource.kind(resource),
      api_version: resource["apiVersion"]
    }

    {measurements, result} = Bonny.Sys.Event.measure(reconcile_callback, [resource])

    case result do
      :ok ->
        Bonny.Sys.Event.reconciler_reconcile_succeeded(measurements, metadata)

      {:ok, _} ->
        Bonny.Sys.Event.reconciler_reconcile_succeeded(measurements, metadata)

      {:error, error} ->
        metadata = Map.put(metadata, :error, error)
        Bonny.Sys.Event.reconciler_reconcile_failed(measurements, metadata)
    end
  end
end
