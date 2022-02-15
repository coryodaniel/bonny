defmodule Bonny.Server.Watcher do
  @moduledoc """
  Creates the stream for watching resources in kubernetes and prepares its processing.

  Watching a resource in kubernetes results in a stream of add/modify/delete events.
  This module uses `K8s.Client.watch_and_stream/3` to create such a stream and maps
  events to a controller's event handler. It is then up to the caller to run the
  resulting stream.

  ## Example

      watch_stream = Bonny.Server.Watcher.get_stream(controller)
      Task.async(fn -> Stream.run(watch_stream) end)
  """

  @callback add(map()) :: :ok | {:ok, any()} | {:error, any()}
  @callback modify(map()) :: :ok | {:ok, any()} | {:error, any()}
  @callback delete(map()) :: :ok | {:ok, any()} | {:error, any()}

  @spec get_stream(module(), K8s.Conn.t(), K8s.Operation.t()) :: Enumerable.t()
  def get_stream(controller, conn, watch_operation) do
    {:ok, watch_stream} = K8s.Client.watch_and_stream(conn, watch_operation)
    Stream.map(watch_stream, &watch_event_handler(controller, &1))
  end

  defp watch_event_handler(controller, %{"type" => type, "object" => resource}) do
    metadata = %{
      module: controller,
      name: K8s.Resource.name(resource),
      namespace: K8s.Resource.namespace(resource),
      kind: K8s.Resource.kind(resource),
      api_version: resource["apiVersion"]
    }

    {measurements, result} =
      case type do
        "ADDED" -> Bonny.Sys.Event.measure(controller, :add, [resource])
        "MODIFIED" -> Bonny.Sys.Event.measure(controller, :modify, [resource])
        "DELETED" -> Bonny.Sys.Event.measure(controller, :delete, [resource])
      end

    case result do
      :ok ->
        Bonny.Sys.Event.watcher_watch_succeeded(measurements, metadata)

      {:ok, _} ->
        Bonny.Sys.Event.watcher_watch_succeeded(measurements, metadata)

      {:error, error} ->
        metadata = Map.put(metadata, :error, error)
        Bonny.Sys.Event.watcher_watch_failed(measurements, metadata)
    end
  end
end
