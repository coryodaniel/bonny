defmodule Bonny.Pluggable.Logger do
  @moduledoc """
  A pluggable step for logging basic action event information in the format:

      {:add, "example.com/v1", "Widget"} - Processing event
      {:add, "example.com/v1", "Widget"} - Status applied
      {:add, "example.com/v1", "Widget"} - Normal event emitted
      {:add, "example.com/v1", "Widget"} - Descendant {"v1", "Deployment", "default/nginx"} applied

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
    action_gvk = {axn.action, axn.resource["apiVersion"], axn.resource["kind"]}

    Logger.log(
      level,
      fn ->
        inspect(action_gvk) <> " - Processing event"
      end,
      resource: axn.resource
    )

    axn
    |> Axn.register_before_apply_status(fn resource, _ ->
      Logger.log(
        level,
        fn ->
          inspect(action_gvk) <> " - Applying status"
        end,
        resource: resource
      )

      resource
    end)
    |> Axn.register_before_apply_descendants(fn descendants, _ ->
      for descendant <- descendants do
        gvkn =
          {descendant["apiVersion"], descendant["kind"],
           descendant["metadata"]["namespace"] <> "/" <> descendant["metadata"]["name"]}

        Logger.log(
          level,
          fn ->
            inspect(action_gvk) <> " - Descendant #{inspect(gvkn)} applied"
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
          inspect(action_gvk) <> " - #{event.event_type} event emitted"
        end,
        resource: axn.resource,
        event: event
      )

      event
    end)
  end
end
