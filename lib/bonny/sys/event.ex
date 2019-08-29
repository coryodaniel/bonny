defmodule Bonny.Sys.Event do
  @moduledoc false
  use Notion, name: :bonny, metadata: %{}

  defevent([:watcher, :initialized])
  defevent([:watcher, :watch, :started])
  defevent([:watcher, :watch, :succeeded])
  defevent([:watcher, :watch, :failed])

  defevent([:reconciler, :initialized])
  defevent([:reconciler, :run, :started])
  defevent([:reconciler, :run, :succeeded])
  defevent([:reconciler, :run, :failed])
  defevent([:reconciler, :fetch, :succeeded])
  defevent([:reconciler, :fetch, :failed])

  defevent([:scheduler, :pods, :fetch, :succeeded])
  defevent([:scheduler, :pods, :fetch, :failed])
  defevent([:scheduler, :nodes, :fetch, :succeeded])
  defevent([:scheduler, :nodes, :fetch, :failed])
  defevent([:scheduler, :binding, :succeeded])
  defevent([:scheduler, :binding, :failed])

  @doc """
  Measure function execution in _ms_ and return in map w/ results.

  ## Examples
      iex> Bonny.Sys.Event.measure(IO, :puts, ["hello"])
      {%{duration: 33}, :ok}
  """
  @spec measure(module, atom, list()) :: {map(), any()}
  def measure(mod, func, args) do
    {duration, result} = :timer.tc(mod, func, args)
    measurements = %{duration: duration}

    {measurements, result}
  end
end
