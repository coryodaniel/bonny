defmodule Bonny.Sys.Telemetry do
  @moduledoc """
  Telemetry event defimitions for this library
  """

  @spans [
    [:reconciler, :reconcile],
    [:watcher, :watch],
    [:scheduler, :binding],
    [:task, :execution]
  ]

  @events Enum.flat_map(@spans, fn span ->
            [
              span ++ [:start],
              span ++ [:stop],
              span ++ [:exception]
            ]
          end)

  @spec events() :: list()
  def events(), do: @events
end
