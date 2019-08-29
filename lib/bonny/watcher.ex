defmodule Bonny.Watcher do
  @moduledoc """
  Dispatches lifecycle functions in response to events from the Kubernetes Watch API for a given controller.
  """

  use GenServer
  require Logger
  alias Bonny.Watcher.{Impl}
  alias Bonny.Server.Watcher.ResponseBuffer
  alias Bonny.{CRD, Telemetry}

  @initial_watch_delay 100

  def start_link(controller) do
    GenServer.start_link(Bonny.Watcher, controller, name: controller)
  end

  @impl GenServer
  def init(controller) do
    state = Impl.new(controller)

    Process.send_after(self(), :watch, @initial_watch_delay)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:watch, %Impl{} = state) do
    # @@
    state = %Impl{state | buffer: ResponseBuffer.new()}
    Impl.watch_for_changes(state, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncHeaders{}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
    # watch succeeded, expect stream
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
    # watch failed
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, %Impl{} = state) do
    # process chunk
    {lines, buffer} =
      state.buffer
      |> ResponseBuffer.add_chunk(chunk)
      |> ResponseBuffer.get_lines()

    case Bonny.Server.Watcher.process_lines(lines, state.resource_version, state.controller) do
      {:ok, new_rv} ->
        {:noreply, %Impl{state | buffer: buffer, resource_version: new_rv}}

      {:error, :gone} ->
        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncEnd{}, %Impl{} = state) do
    # watch finished
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.Error{reason: {:closed, :timeout}}, %Impl{} = state) do
    # watch expired / timedout
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, reason}, %Impl{} = state) do
    # GenServer down
    Logger.warn("DOWN received (#{inspect(pid)}) reason: #{inspect(reason)} #{inspect(self())}")

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(other, %Impl{} = state) do
    Logger.warn("Received unhandled info: #{inspect(other)}")
    {:noreply, state}
  end
end
