defmodule Bonny.Sys.Logger do
  @moduledoc """
  Attaches telemetry events to the Elixir Logger
  """

  require Logger

  @spec attach() :: :ok
  @doc """
  Attaches telemetry events to the Elixir Logger
  """
  def attach() do
    events = Bonny.Sys.Telemetry.events()
    :telemetry.attach_many("bonny-events-logger", events, &log_handler/4, :debug)
  end

  @doc false
  @spec log_handler(keyword, map | integer, map, atom) :: :ok
  def log_handler(event, measurements, metadata, preferred_level) do
    event_name = Enum.join(event, ".")

    level =
      case Regex.match?(~r/fail|error/, event_name) do
        true -> :error
        _ -> preferred_level
      end

    Logger.log(level, "[#{event_name}] #{inspect(measurements)} #{inspect(metadata)}")
  end
end
