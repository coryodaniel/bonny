defmodule Bonny.PeriodicTask.Runner do
  @moduledoc false
  use GenServer
  require Logger
  alias Bonny.PeriodicTask

  @spec start_link(PeriodicTask.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(%PeriodicTask{id: id} = task) do
    GenServer.start_link(__MODULE__, task, name: id)
  end

  @impl true
  def init(%PeriodicTask{} = task) do
    Logger.info("Task initialized", %{id: task.id, library: :bonny})
    Process.send_after(self(), :run, calc_offset(task))
    {:ok, task}
  end

  @impl true
  def handle_info(:run, %PeriodicTask{} = task) do
    metadata = %{id: task.id, library: :bonny}

    :telemetry.span([:task, :execution], metadata, fn ->
      Logger.info("Task execution started", metadata)

      case execute(task) do
        {:ok, new_state} ->
          Logger.debug("Task execution succeeded", metadata)
          task = %PeriodicTask{task | state: new_state}
          Process.send_after(self(), :run, calc_offset(task))
          {{:noreply, task}, metadata}

        :ok ->
          Logger.debug("Task execution succeeded", metadata)
          Process.send_after(self(), :run, calc_offset(task))
          {{:noreply, task}, metadata}

        {:stop, reason} ->
          metadata = Map.put(metadata, :reason, reason)
          Logger.info("Task execution stopped", metadata)
          {{:noreply, {:stop, reason, task}}, metadata}

        other ->
          metadata = Map.put(metadata, :error, other)
          Logger.error("Task execution failed", metadata)
          {{:noreply, {:stop, :error, other}}, metadata}
      end
    end)
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
