defmodule Bonny.Watcher do
  @moduledoc """
  Dispatches lifecycle functions in response to events from the Kubernetes Watch API for a given controller.
  """

  use GenServer
  alias Bonny.Watcher.Impl
  require Logger

  def start_link(controller) do
    GenServer.start_link(Bonny.Watcher, controller, name: controller)
  end

  @impl GenServer
  def init(controller) do
    state = Impl.new(controller)
    Logger.debug(fn -> "Starting new Bonny.Watcher #{inspect(state)}" end)
    schedule_watcher()
    {:ok, state}
  end

  defp schedule_watcher() do
    Process.send_after(self(), :watch, 5000)
  end

  def handle_info(:watch, state) do
    {:ok, state} = Impl.get_resource_version(state)
    Logger.debug(fn -> "Starting watch from resource version: #{state.resource_version}" end)
    Impl.watch_for_changes(state, self())

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state), do: {:noreply, state}

  def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
    Logger.debug(fn -> "Received HTTP error from Kubernetes API: #{code}" end)
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
    Logger.debug(fn -> "Received async end: #{state.resource_version}" end)
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.Error{reason: {:closed, :timeout}}, state = %Impl{}) do
    Logger.debug(fn -> "Received timeout: #{state.resource_version}" end)
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(other, state = %Impl{}) do
    Logger.warn(fn -> "Received unhandled info: #{inspect(other)}" end)
    {:noreply, state}
  end
end
