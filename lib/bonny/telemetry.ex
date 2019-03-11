defmodule Bonny.Telemetry do

  @spec events() :: list(list(atom))
  def events() do
    [
      [:bonny, :test]
    ]
  end

  def measure(function) do
    function
    |> :timer.tc
    |> elem(0)
    |> Kernel./(1_000_000)
  end

  def test() do
    latency = measure fn -> :timer.sleep(100) end
    :telemetry.execute([:bonny, :test], %{latency: latency}, %{controller: "foo"})
  end

  def attach() do
    :telemetry.attach_many("log-handler", events(), &Bonny.Telemetry.DebugLogger.handle_event/4, nil)
  end
end

defmodule Bonny.Telemetry.DebugLogger do
  require Logger

  def handle_event(event, measurements, metadata, _config) do
    Logger.debug(fn ->
      event_name = Enum.join(event, ":")
      "[#{event_name}] #{inspect(measurements)} #{inspect(metadata)}"
    end)
  end
end
