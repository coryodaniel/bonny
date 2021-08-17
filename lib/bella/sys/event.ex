defmodule Bella.Sys.Event do
  @moduledoc false
  use Notion, name: :bella, metadata: %{}

  defevent([:watcher, :initialized])
  defevent([:watcher, :watch, :started])
  defevent([:watcher, :watch, :succeeded])
  defevent([:watcher, :watch, :finished])
  defevent([:watcher, :watch, :failed])
  defevent([:watcher, :watch, :timedout])
  defevent([:watcher, :chunk, :received])
  defevent([:watcher, :genserver, :down])

  defevent([:reconciler, :initialized])
  defevent([:reconciler, :fetch, :succeeded])
  defevent([:reconciler, :fetch, :failed])
  defevent([:reconciler, :run, :started])
  defevent([:reconciler, :reconcile, :succeeded])
  defevent([:reconciler, :reconcile, :failed])
  defevent([:reconciler, :genserver, :down])

  defevent([:scheduler, :pods, :fetch, :succeeded])
  defevent([:scheduler, :pods, :fetch, :failed])
  defevent([:scheduler, :nodes, :fetch, :succeeded])
  defevent([:scheduler, :nodes, :fetch, :failed])
  defevent([:scheduler, :binding, :succeeded])
  defevent([:scheduler, :binding, :failed])

  defevent([:task, :initialized])
  defevent([:task, :registered])
  defevent([:task, :unregistered])
  defevent([:task, :succeeded])
  defevent([:task, :failed])
  defevent([:task, :stopped])

  @doc """
  Measure function execution in _ms_ and return in map w/ results.

  ## Examples
      iex> Bella.Sys.Event.measure(IO, :puts, ["hello"])
      {%{duration: 33}, :ok}
  """
  @spec measure(module, atom, list()) :: {map(), any()}
  def measure(mod, func, args) do
    {duration, result} = :timer.tc(mod, func, args)
    measurements = %{duration: duration}

    {measurements, result}
  end
end
