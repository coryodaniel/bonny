defmodule Bonny.Telemetry do
  @moduledoc """
  List of telemetry events.
  """
  @spec events() :: list(list(atom))
  def events() do
    [
      [:bonny, :watcher, :initialized],
      [:bonny, :watcher, :started],
      [:bonny, :watcher, :dispatched]
    ]
  end

  @doc """
  Emits telemetry.

  **Note:** This method switches the order of `measurements` and `metadata`
  """
  @spec emit(atom) :: no_return
  @spec emit(atom, fun) :: no_return
  @spec emit(atom, map) :: no_return
  @spec emit(atom, map, map) :: no_return
  @spec emit(atom, map, fun) :: no_return
  @spec emit(list(atom), map, fun) :: no_return
  def emit(name), do: emit(name, %{}, %{})
  def emit(name, metadata = %{}), do: emit(name, %{}, metadata)
  def emit(name, func) when is_function(func), do: emit(name, %{}, func)

  def emit(name, metadata = %{}, func) when is_function(func),
    do: emit(name, metadata, %{duration: measure(func)})

  def emit(name, metadata = %{}, measurements = %{}) when is_atom(name),
    do: emit([name], measurements, metadata)

  def emit(names, metadata = %{}, measurements = %{}) when is_list(names),
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

  @spec attach() :: no_return
  @doc false
  def attach() do
    :telemetry.attach_many(
      "debug-logger",
      events(),
      &Bonny.Telemetry.DebugLogger.handle_event/4,
      nil
    )
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
