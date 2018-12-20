defmodule Bonny.Watcher do
  @moduledoc false
  use GenServer
  alias Bonny.Watcher.Impl
  require Logger

  def start_link(operator) do
    GenServer.start_link(Bonny.Watcher, operator, name: operator)
  end

  @impl true
  def init(operator) do
    state = Impl.new(operator)
    schedule_watcher()
    {:ok, state}
  end

  defp schedule_watcher() do
    Process.send_after(self(), :watch, 5000)
  end

  def handle_info(:watch, state) do
    {:ok, state} = Impl.get_resource_version(state)
    Logger.debug("Starting watch from resource version: #{state.resource_version}")
    Impl.watch_for_changes(state, self())

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state), do: {:noreply, state}

  def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
    Logger.debug("Received HTTP error from Kubernetes API: #{code}")
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncHeaders{}, state), do: {:noreply, state}

  @impl GenServer
  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, state = %Impl{}) do
    chunk
    |> Impl.parse_chunk()
    |> Impl.dispatch(state.mod)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncEnd{}, state = %Impl{}) do
    Logger.debug("Received async end: #{state.resource_version}")
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.Error{reason: {:closed, :timeout}}, state = %Impl{}) do
    Logger.debug("Received timeout: #{state.resource_version}")
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(other, state = %Impl{}) do
    Logger.warn("Received unhandled info: #{inspect(other)}")
    {:noreply, state}
  end
end
