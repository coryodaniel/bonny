defmodule Bonny.Watcher do
  @moduledoc """
  Dispatches lifecycle functions in response to events from the Kubernetes Watch API for a given controller.
  """

  use GenServer
  require Logger
  alias Bonny.Watcher.{Impl, ResponseBuffer}
  alias Bonny.{CRD, Telemetry}

  @initial_watch_delay 100

  def start_link(controller) do
    GenServer.start_link(Bonny.Watcher, controller, name: controller)
  end

  @impl GenServer
  def init(controller) do
    state = Impl.new(controller)
    emit_telemetry_event(:genserver_initialized, state)

    Process.send_after(self(), :watch, @initial_watch_delay)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:watch, %Impl{} = state) do
    emit_telemetry_event(:started, state)

    state = %Impl{state | buffer: ResponseBuffer.new()}
    Impl.watch_for_changes(state, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncHeaders{}, state), do: {:noreply, state}

  @impl GenServer
  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
    emit_telemetry_event(:http_request_succeeded, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
    emit_telemetry_event(:http_request_failed, state, %{code: code})
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, %Impl{} = state) do
    emit_telemetry_event(:chunk_received, state)

    {lines, buffer} =
      state.buffer
      |> ResponseBuffer.add_chunk(chunk)
      |> ResponseBuffer.get_lines()

    case Impl.process_lines(state, lines) do
      {:ok, new_rv} ->
        {:noreply, %Impl{state | buffer: buffer, resource_version: new_rv}}

      {:error, :gone} ->
        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncEnd{}, %Impl{} = state) do
    emit_telemetry_event(:finished, state)
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.Error{reason: {:closed, :timeout}}, %Impl{} = state) do
    emit_telemetry_event(:expired, state)
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, reason}, %Impl{} = state) do
    emit_telemetry_event(:genserver_down, state, %{reason: reason})
    Logger.warn("DOWN received (#{inspect(pid)}) reason: #{inspect(reason)} #{inspect(self())}")

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(other, %Impl{} = state) do
    Logger.warn("Received unhandled info: #{inspect(other)}")
    {:noreply, state}
  end

  @spec emit_telemetry_event(atom, Impl.t(), map) :: :ok
  defp emit_telemetry_event(name, state, extra \\ %{}) do
    metadata = CRD.telemetry_metadata(state.spec, extra)
    Telemetry.emit([:watcher, name], %{}, metadata)
  end
end
