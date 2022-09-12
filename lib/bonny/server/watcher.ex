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

  @operations %{
    "ADDED" => :add,
    "MODIFIED" => :modify,
    "DELETED" => :delete
  }

  @spec get_stream(module(), K8s.Conn.t(), K8s.Operation.t(), Keyword.t()) :: Enumerable.t()
  def get_stream(controller, conn, watch_operation, opts \\ []) do
    skip_observed_generations = Keyword.get(opts, :skip_observed_generations, false)
    plural = Bonny.ControllerV2.crd(controller).names.plural
    {:ok, watch_stream} = K8s.Client.watch_and_stream(conn, watch_operation)

    watch_stream
    |> Stream.reject(&skip_resource?(&1, skip_observed_generations))
    |> Stream.map(&run_action_callbacks(controller, &1))
    |> Stream.reject(&(&1 == :error))
    |> Stream.map(fn resource ->
      if skip_observed_generations,
        do: Bonny.Resource.set_observed_generation(resource),
        else: resource
    end)
    |> Stream.map(&Bonny.Resource.apply_status(&1, plural, conn))
  end

  defp run_action_callbacks(
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
      case apply(controller, @operations[type], [resource]) do
        :ok ->
          {resource, metadata}

        {:ok, _} ->
          {resource, metadata}

        {:error, error} ->
          {:error, Map.put(metadata, :error, error)}
      end
    end)
  end

  defp skip_resource?(_, false), do: false
  defp skip_resource?(%{"type" => "DELETED"}, _), do: false

  defp skip_resource?(%{"object" => resource}, _) do
    # skip resource if generation has been observed
    get_in(resource, ~w(metadata generation)) ==
      get_in(resource, [Access.key("status", %{}), "observedGeneration"])
  end
end
