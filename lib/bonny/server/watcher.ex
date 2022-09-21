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

  @type action :: :add | :modify | :delete
  @type watch_event :: {action(), Bonny.Resource.t()}

  @operations %{
    "ADDED" => :add,
    "MODIFIED" => :modify,
    "DELETED" => :delete
  }

  @spec get_raw_stream(K8s.Conn.t(), K8s.Operation.t()) :: Enumerable.t(watch_event())
  def get_raw_stream(conn, watch_operation) do
    {:ok, watch_stream} = K8s.Client.watch_and_stream(conn, watch_operation)

    watch_stream
    |> Stream.map(fn %{"type" => type, "object" => resource} -> {@operations[type], resource} end)
  end

  @spec get_stream(module(), K8s.Conn.t(), K8s.Operation.t()) ::
          Enumerable.t(Bonny.Resource.t())
  def get_stream(controller, conn, watch_operation) do
    get_raw_stream(conn, watch_operation)
    |> Stream.map(&run_action_callbacks(controller, &1))
    |> Stream.reject(&(&1 == :error))
  end

  defp run_action_callbacks(
         controller,
         {type, resource}
       ) do
    metadata = %{
      module: controller,
      name: K8s.Resource.name(resource),
      namespace: K8s.Resource.namespace(resource),
      kind: K8s.Resource.kind(resource),
      api_version: resource["apiVersion"]
    }

    :telemetry.span([:watcher, :watch], metadata, fn ->
      case apply(controller, type, [resource]) do
        :ok ->
          {resource, metadata}

        {:ok, _} ->
          {resource, metadata}

        {:error, error} ->
          {:error, Map.put(metadata, :error, error)}
      end
    end)
  end
end
