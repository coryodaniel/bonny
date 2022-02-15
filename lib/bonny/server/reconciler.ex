defmodule Bonny.Server.Reconciler do
  @moduledoc """
  Creates a stream that, when run, streams a list of resources and calls `reconcile/1`
  on the given controller for each resource in the stream in parallel.

  ## Example

      reconciliation_stream = Bonny.Server.Reconciler.get_stream(controller)
      Task.async(fn -> Stream.run(reconciliation_stream) end)
  """

  @doc """
  Takes a controller that must define the following functions and returns a (prepared) stream.

  * `conn/0` - should return a K8s.Conn.t()
  * `reconcile_operation/0` - should return a K8s.Operation.t() list operation that produces the stream of resources
  * `reconcile/1` - takes a map and processes it
  """

  @callback reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}

  def get_stream(controller, conn, reconcile_operation, opts \\ []) do
    {:ok, reconciliation_stream} = K8s.Client.stream(conn, reconcile_operation, opts)
    reconcile_all(reconciliation_stream, controller)
  end

  defp reconcile_all(resource_stream, controller) do
    resource_stream
    |> Task.async_stream(fn
      resource when is_map(resource) ->
        reconcile_single_resource(resource, controller)
        metadata = %{module: controller}
        Bonny.Sys.Event.reconciler_fetch_succeeded(metadata)

        resource

      {:error, error} ->
        metadata = %{module: controller, error: error}
        Bonny.Sys.Event.reconciler_fetch_failed(metadata)

        error

    end, ordered: false)
  end

  defp reconcile_single_resource(resource, controller) do
    metadata = %{
      module: controller,
      name: K8s.Resource.name(resource),
      namespace: K8s.Resource.namespace(resource),
      kind: K8s.Resource.kind(resource),
      api_version: resource["apiVersion"]
    }

    {measurements, result} = Bonny.Sys.Event.measure(controller, :reconcile, [resource])

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
