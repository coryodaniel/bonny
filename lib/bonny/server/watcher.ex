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

  @spec get_stream(module(), K8s.Conn.t(), K8s.Operation.t(), Keyword.t()) :: Enumerable.t()
  def get_stream(controller, conn, watch_operation, opts \\ []) do
    reject_observed_genrations = Keyword.get(opts, :skip_observed_generations, false)
    {:ok, watch_stream} = K8s.Client.watch_and_stream(conn, watch_operation)

    watch_stream
    |> Stream.reject(&(reject_observed_genrations && observed_generation?(&1)))
    |> Stream.map(&watch_event_handler(controller, &1))
    |> Stream.map(fn
      {:ok, resource} when reject_observed_genrations ->
        set_observed_generations(resource, controller, conn)
        :ok

      {:ok, _resource} ->
        :ok

      other ->
        other
    end)
  end

  defp watch_event_handler(
         controller,
         %{"type" => type, "object" => resource}
       ) do
    metadata = %{
      module: controller,
      name: K8s.Resource.name(resource),
      namespace: K8s.Resource.namespace(resource),
      kind: K8s.Resource.kind(resource),
      api_version: resource["apiVersion"]
    }

    :telemetry.span([:watcher, :watch], metadata, fn ->
      operation =
        case type do
          "ADDED" -> :add
          "MODIFIED" -> :modify
          "DELETED" -> :delete
        end

      case apply(controller, operation, [resource]) do
        :ok ->
          {{:ok, resource}, metadata}

        {:ok, _} ->
          {{:ok, resource}, metadata}

        {:error, error} ->
          {:error, Map.put(metadata, :error, error)}
      end
    end)
  end

  defp set_observed_generations(resource, controller, conn) do
    generation = get_in(resource, ~w(metadata generation))

    {_, updated_resource} =
      resource
      |> put_in([Access.key("status", %{}), "observedGeneration"], generation)
      |> pop_in(~w(metadata managedFields))

    path = Bonny.ControllerV2.crd(controller).names.plural <> "/status"

    op =
      K8s.Client.apply(
        resource["apiVersion"],
        path,
        [namespace: K8s.Resource.namespace(resource), name: K8s.Resource.name(resource)],
        updated_resource,
        field_manager: Bonny.Config.name(),
        force: true
      )

    {:ok, _} = K8s.Client.run(conn, op)
  end

  defp observed_generation?(%{"type" => "DELETED"}), do: false

  defp observed_generation?(%{"object" => resource}) do
    get_in(resource, ~w(metadata generation)) ==
      get_in(resource, [Access.key("status", %{}), "observedGeneration"])
  end
end
