defmodule Bonny.Server.Reconciler do
  @moduledoc """
  Creates a stream that, when run, streams a list of resources and calls `reconcile/1`
  on the given controller for each resource in the stream in parallel.

  ## Example

      reconciliation_stream = Bonny.Server.Reconciler.get_stream(controller)
      Task.async(fn -> Stream.run(reconciliation_stream) end)
  """

  require Logger

  @callback reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}

  @doc """
  """
  @spec get_raw_stream(K8s.Conn.t(), K8s.Operation.t(), keyword()) :: Enumerable.t()
  def get_raw_stream(conn, reconcile_operation, stream_opts \\ []) do
    {:ok, reconciliation_stream} = K8s.Client.stream(conn, reconcile_operation, stream_opts)

    Stream.filter(reconciliation_stream, &fetch_succeeded?/1)
  end

  @doc """
  Prepares a stream wich maps each resoruce returned by the `reconcile_operation` to
  a function `reconcile/1` on the given `module`. If given, the stream_opts are passed
  to K8s.Client.stream/3
  """
  @spec get_stream(module(), K8s.Conn.t(), K8s.Operation.t(), keyword()) ::
          Enumerable.t(Bonny.Resource.t())
  def get_stream(module, conn, reconcile_operation, stream_opts \\ []) do
    get_raw_stream(conn, reconcile_operation, stream_opts)
    |> Task.async_stream(&reconcile_single_resource(&1, module))
    |> Stream.filter(&match?({:ok, {:ok, _}}, &1))
    |> Stream.map(fn {:ok, {:ok, resource}} -> resource end)
  end

  defp fetch_succeeded?({:error, error}) do
    Logger.debug("Reconciler fetch failed", %{error: error, library: :bonny})
    false
  end

  defp fetch_succeeded?(resource) when is_map(resource) do
    Logger.debug("Reconciler fetch succeeded", library: :bonny)
    true
  end

  defp reconcile_single_resource(resource, module) do
    metadata = %{
      module: module,
      name: K8s.Resource.name(resource),
      namespace: K8s.Resource.namespace(resource),
      kind: K8s.Resource.kind(resource),
      api_version: resource["apiVersion"],
      library: :bonny
    }

    :telemetry.span([:reconciler, :reconcile], metadata, fn ->
      case module.reconcile(resource) do
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
