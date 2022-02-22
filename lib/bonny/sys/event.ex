defmodule Bonny.Sys.Event do
  @deprecated "Use Bonny.Sys.Telemetry instead"
  @moduledoc false

  @spec events() :: list()
  defdelegate events, to: Bonny.Sys.Telemetry
end
