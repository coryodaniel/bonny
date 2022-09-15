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

  require Logger

  @callback reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}

  @spec get_stream(module(), K8s.Conn.t(), K8s.Operation.t(), keyword()) ::
          Enumerable.t(Bonny.Resource.t())
  def get_stream(controller, conn, reconcile_operation, opts \\ []) do
    {:ok, reconciliation_stream} = K8s.Client.stream(conn, reconcile_operation, opts)

    reconciliation_stream
    |> Stream.filter(&fetch_succeeded?/1)
    |> Task.async_stream(&reconcile_single_resource(&1, controller))
    |> Stream.filter(&match?({:ok, {:ok, _}}, &1))
    |> Stream.map(fn {:ok, {:ok, resource}} -> resource end)
  end

  defp fetch_succeeded?({:error, error}) do
    Logger.debug("Reconciler fetch failed", %{error: error})
    false
  end

  defp fetch_succeeded?(resource) when is_map(resource) do
    Logger.debug("Reconciler fetch succeeded")
    true
  end

  defp reconcile_single_resource(resource, controller) do
    metadata = %{
      module: controller,
      name: K8s.Resource.name(resource),
      namespace: K8s.Resource.namespace(resource),
      kind: K8s.Resource.kind(resource),
      api_version: resource["apiVersion"]
    }

    :telemetry.span([:reconciler, :reconcile], metadata, fn ->
      case controller.reconcile(resource) do
        :ok ->
          Logger.debug("Reconciler reconciliation succeeded", metadata)
          {{:ok, resource}, metadata}

        {:ok, _} ->
          Logger.debug("Reconciler reconciliation succeeded", metadata)
          {{:ok, resource}, metadata}

        {:error, error} ->
          metadata = Map.put(metadata, :error, error)
          Logger.error("Reconciler reconciliation failed", metadata)
          {:error, metadata}
      end
    end)
  end
end
