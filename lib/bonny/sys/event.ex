defmodule Bonny.Sys.Event do
  @deprecated "Use Bonny.Sys.Telemetry instead"
  @moduledoc """
  Telemetry event defimitions for this library
  """

  @spec events() :: list()
  defdelegate events, to: Bonny.Sys.Telemetry
end
