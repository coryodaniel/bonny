defmodule Bonny.PeriodicTask.Runner do
  @moduledoc """

  """

  use GenServer
  use Bitwise
  require Logger
  alias Bonny.PeriodicTask

  # TODO:
  # defevent([:task, :started])
  # defevent([:task, :skipped])
  # defevent([:task, :succeeded])
  # defevent([:task, :failed])
  # defevent([:task, :scheduled])

  @spec start_link(PeriodicTask.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(%PeriodicTask{id: id} = task) do
    GenServer.start_link(__MODULE__, task, name: id)
  end

  @impl true
  def init(%PeriodicTask{id: id} = task) do
    Process.send_after(self(), :run, calc_offset(task))
    {:ok, task}
  end

  @impl true
  def handle_info(:run, %PeriodicTask{} = task) do
    new_task =
      case execute(task) do
        {:ok, new_state} ->
          task = %PeriodicTask{task | state: new_state}
          Process.send_after(self(), :run, calc_offset(task))
          task

        :ok ->
          Process.send_after(self(), :run, calc_offset(task))
          task
      end

    # :ok, {:ok, state},
    #     { :stop, reason } ->
    #   { :stop, reason, task_state }

    # other ->
    #   { :stop, :error, other }

    {:noreply, new_task}
  end

  defp calc_offset(%PeriodicTask{interval: int, jitter: jitter} = task) do
    jitter = :rand.uniform() * int * jitter
    round(int + jitter)
  end

  defp execute(%PeriodicTask{handler: fun, state: state}) when is_function(fun) do
    fun.(state)
  end

  defp execute(%PeriodicTask{handler: {m, f}, state: state}) do
    apply(m, f, [state])
  end

  defp execute(%PeriodicTask{handler: {m, f, a}}) do
    apply(m, f, a)
  end
end
