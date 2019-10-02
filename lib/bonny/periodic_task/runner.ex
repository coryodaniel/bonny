defmodule Bonny.PeriodicTask.Runner do
  @moduledoc false
  use GenServer
  use Bitwise
  require Logger
  alias Bonny.PeriodicTask
  alias Bonny.Sys.Event

  @spec start_link(PeriodicTask.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(%PeriodicTask{id: id} = task) do
    GenServer.start_link(__MODULE__, task, name: id)
  end

  @impl true
  def init(%PeriodicTask{} = task) do
    Event.task_initialized(%{}, %{id: task.id})
    Process.send_after(self(), :run, calc_offset(task))
    {:ok, task}
  end

  @impl true
  def handle_info(:run, %PeriodicTask{} = task) do
    next_task =
      case execute(task) do
        {:ok, new_state} ->
          Event.task_succeeded(%{}, %{id: task.id})
          task = %PeriodicTask{task | state: new_state}
          Process.send_after(self(), :run, calc_offset(task))
          task

        :ok ->
          Event.task_succeeded(%{}, %{id: task.id})
          Process.send_after(self(), :run, calc_offset(task))
          task

        {:stop, reason} ->
          Event.task_stopped(%{}, %{id: task.id})
          {:stop, reason, task}

        other ->
          Event.task_failed(%{}, %{id: task.id})
          {:stop, :error, other}
      end

    {:noreply, next_task}
  end

  defp calc_offset(%PeriodicTask{interval: int, jitter: jitter}) do
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
