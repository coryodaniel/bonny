defmodule Bonny.Telemetry do
  @moduledoc """
  List of telemetry events.
  """

  @reconciler_events [
    :genserver_initialized,
    :started,
    :scheduled,
    :get_items_succeeded,
    :get_items_failed,
    :item_succeeded,
    :item_failed
  ]

  @watcher_events [
    :genserver_initialized,
    :genserver_down,
    :started,
    :chunk_received,
    :expired,
    :finished,
    :http_request_failed,
    :http_request_succeeded,
    :dispatch_succeeded,
    :dispatch_failed
  ]

  @spec events() :: list(list(atom))
  def events() do
    reconciler_events = Enum.map(@reconciler_events, fn event -> [:bonny, :reconciler, event] end)
    watcher_events = Enum.map(@watcher_events, fn event -> [:bonny, :watcher, event] end)

    reconciler_events ++ watcher_events
  end

  @doc """
  Wrapper around `:telemetry.execute/3`.

  Prepends `:bonnny` to all atom lists.
  """
  @spec emit(list(atom)) :: :ok
  def emit(names), do: emit(names, %{}, %{})

  @spec emit(list(atom), map, map) :: :ok
  def emit(names, %{} = measurements, %{} = metadata),
    do: :telemetry.execute([:bonny | names], measurements, metadata)

  @doc """
  Measures a functions execution time in seconds

  ## Examples

      iex> Bonny.Telemetry.measure fn ->
      ...>   :timer.sleep(1000)
      ...>   "Hello!"
      ...> end
      {1.00426, "Hello!"}
  """
  @spec measure(fun) :: {float(), any()}
  def measure(function) do
    {elapsed, retval} = :timer.tc(function)
    seconds = elapsed / 1_000_000
    {seconds, retval}
  end
end

defmodule Bonny.Telemetry.DebugLogger do
  @moduledoc """
  A telemetry logger for debugging.
  """
  require Logger

  def handle_event(event, measurements, metadata, _config) do
    Logger.debug(fn ->
      event_name = Enum.join(event, "_")
      "[#{event_name}] #{inspect(measurements)} #{inspect(metadata)}"
    end)
  end

  @doc false
  @spec attach() :: no_return
  def attach() do
    :telemetry.attach_many(
      "debug-logger",
      Bonny.Telemetry.events(),
      &Bonny.Telemetry.DebugLogger.handle_event/4,
      nil
    )
  end
end
