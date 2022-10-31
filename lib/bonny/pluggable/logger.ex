defmodule Bonny.Pluggable.Logger do
  @moduledoc """
  A pluggable step for logging basic action event information in the format:

      {"NAMESPACE/OBJECT_NAME", API_VERSION, "Kind=KIND, Action=ACTION"}

  Example:

      {"default/my-object", "example.com/v1", "Kind=MyCustomResource, Action=:add"} - Processing event
      {"default/my-object", "example.com/v1", "Kind=MyCustomResource, Action=:add"} - Applying status
      {"default/my-object", "example.com/v1", "Kind=MyCustomResource, Action=:add"} - Emitting Normal event
      {"default/my-object", "example.com/v1", "Kind=MyCustomResource, Action=:add"} - Applying descendant {"default/nginx", "apps/v1", "Kind=Deployment"}

  To use it, just add a step to the desired module.

      step Bonny.Pluggable.Logger, level: :debug

  ## Options

    * `:level` - The log level at which this plug should log its request info.
      Default is `:info`.
      The [list of supported levels](https://hexdocs.pm/logger/Logger.html#module-levels)
      is available in the `Logger` documentation.

  """

  alias Bonny.Axn
  require Logger
  @behaviour Pluggable

  def init(opts), do: Keyword.get(opts, :level, :info)

  def call(axn, level) do
    id = Axn.identifier(axn)

    Logger.log(
      level,
      fn ->
        inspect(id) <> " - Processing event"
      end,
      resource: axn.resource
    )

    axn
    |> Axn.register_before_apply_status(fn resource, _ ->
      Logger.log(
        level,
        fn ->
          inspect(id) <> " - Applying status"
        end,
        resource: resource
      )

      resource
    end)
    |> Axn.register_before_apply_descendants(fn descendants, _ ->
      for descendant <- descendants do
        gvkn = Bonny.Resource.gvkn(descendant)

        Logger.log(
          level,
          fn ->
            inspect(id) <> " - Applying descendant #{inspect(gvkn)}"
          end,
          resource: axn.resource,
          descendant: descendant
        )

        descendant
      end
    end)
    |> Axn.register_before_emit_event(fn event, _ ->
      Logger.log(
        level,
        fn ->
          inspect(id) <> " - Emitting #{event.event_type} event"
        end,
        resource: axn.resource,
        event: event
      )

      event
    end)
  end
end
