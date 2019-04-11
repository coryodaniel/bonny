defmodule Bonny.Watcher do
  @moduledoc """
  Dispatches lifecycle functions in response to events from the Kubernetes Watch API for a given controller.
  """

  use GenServer
  alias Bonny.Watcher.{Impl, ResponseBuffer}
  require Logger
  @initial_watch_delay 3000

  def start_link(controller) do
    GenServer.start_link(Bonny.Watcher, controller, name: controller)
  end

  @impl GenServer
  def init(controller) do
    state = Impl.new(controller)
    Process.send_after(self(), :watch, @initial_watch_delay)
    {:ok, state}
  end

  def handle_info(:watch, state = %Impl{}) do
    state = %Impl{state | buffer: ResponseBuffer.new()}
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
    {lines, buffer} =
      state.buffer
      |> ResponseBuffer.add_chunk(chunk)
      |> ResponseBuffer.get_lines()

    case process_lines(state, lines) do
      {:ok, new_rv} ->
        {:noreply, %Impl{state | buffer: buffer, resource_version: new_rv}}

      {:error, :gone} ->
        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(%HTTPoison.AsyncEnd{}, state = %Impl{}) do
    Logger.debug(fn -> "Received async end: #{inspect(state)}" end)
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%HTTPoison.Error{reason: {:closed, :timeout}}, state = %Impl{}) do
    Logger.debug(fn -> "Received timeout: #{inspect(state)}" end)
    send(self(), :watch)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, reason}, state = %Impl{}) do
    Logger.warn(fn ->
      "DOWN received (#{inspect(pid)}) reason: #{inspect(reason)}\n#{inspect(self())}"
    end)

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(other, state = %Impl{}) do
    Logger.warn(fn -> "Received unhandled info: #{inspect(other)}" end)
    {:noreply, state}
  end

  defp process_lines(state = %Impl{resource_version: rv}, lines) do
    Enum.reduce(lines, {:ok, rv}, fn line, status ->
      case status do
        {:ok, current_rv} ->
          process_line(line, current_rv, state)

        {:error, :gone} ->
          {:error, :gone}
      end
    end)
  end

  defp process_line(line, current_rv, state = %Impl{}) do
    %{"type" => type, "object" => raw_object} = Jason.decode!(line)

    case Impl.extract_rv(raw_object) do
      {:gone, message} ->
        Logger.debug(fn -> "Received 410: #{message}." end)
        {:error, :gone}

      ^current_rv ->
        Logger.debug(fn -> "Duplicate message: #{type}, resourceVersion: #{current_rv}." end)
        {:ok, current_rv}

      new_rv ->
        Logger.debug(fn -> "Received message: #{type}, resourceVersion: #{new_rv}" end)
        Impl.dispatch(%{"type" => type, "object" => raw_object}, state.controller)
        {:ok, new_rv}
    end
  end
end
