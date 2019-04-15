defmodule Bonny.Watcher.Impl do
  @moduledoc """
  Implementation logic for `Bonny.Watcher`
  """

  alias Bonny.Watcher.{Impl, ResponseBuffer}
  alias Bonny.{Config, CRD, Telemetry}
  require Logger

  @client Application.get_env(:bonny, :k8s_client, K8s.Client)
  @timeout Application.get_env(:bonny, :watch_timeout, 5 * 60 * 1000)
  @type t :: %__MODULE__{
          spec: CRD.t(),
          controller: atom(),
          resource_version: String.t() | nil,
          buffer: ResponseBuffer.t()
        }

  defstruct [:spec, :controller, :resource_version, :buffer]

  @doc """
  Initialize a `Bonny.Watcher` state
  """
  @spec new(module()) :: Impl.t()
  def new(controller) do
    spec = apply(controller, :crd_spec, [])

    %__MODULE__{
      controller: controller,
      spec: spec,
      resource_version: nil,
      buffer: ResponseBuffer.new()
    }
  end

  @doc """
  Watches a CRD resource for `ADDED`, `MODIFIED`, and `DELETED` events from the Kubernetes API.

  Streams HTTPoison response to `Bonny.Watcher`
  """
  @spec watch_for_changes(Impl.t(), pid()) :: no_return
  def watch_for_changes(state = %Impl{}, watcher) do
    operation = list_operation(state)
    rv = get_resource_version(state)

    @client.watch(operation, Config.cluster_name(),
      params: %{resourceVersion: rv},
      stream_to: watcher,
      recv_timeout: @timeout
    )
  end

  @doc """
  Gets the resource version from the state, or fetches it from Kubernetes API if not present
  """
  @spec get_resource_version(Impl.t()) :: binary
  def get_resource_version(state = %Impl{}) do
    case state.resource_version do
      nil ->
        case fetch_resource_version(state) do
          {:ok, rv} ->
            rv

          {:error, msg} ->
            Logger.warn("Error fetching resource version: #{msg}")
            "0"
        end

      rv ->
        rv
    end
  end

  @doc """
  Dispatches an `ADDED`, `MODIFIED`, and `DELETED` events to an controller
  """
  @spec dispatch(map, atom) :: no_return
  def dispatch(%{"type" => "ADDED", "object" => object}, controller),
    do: do_dispatch(controller, :add, object)

  def dispatch(%{"type" => "MODIFIED", "object" => object}, controller),
    do: do_dispatch(controller, :modify, object)

  def dispatch(%{"type" => "DELETED", "object" => object}, controller),
    do: do_dispatch(controller, :delete, object)

  @spec do_dispatch(atom, atom, map) :: no_return
  defp do_dispatch(controller, event, object) do
    Task.start(fn ->
      {time, result} = Telemetry.measure(fn -> apply(controller, event, [object]) end)
      measurements = %{duration: time}

      case result do
        :ok ->
          emit_telemetry_measurement(:dispatch_succeeded, measurements, controller)

        {:error, msg} ->
          emit_telemetry_measurement(:dispatch_failed, measurements, controller)
          Logger.error("Error dispatching watch event: #{msg}")
      end
    end)
  end

  @spec list_operation(Impl.t()) :: K8s.Operation.t()
  defp list_operation(state = %Impl{}) do
    api_version = CRD.api_version(state.spec)
    name = CRD.kind(state.spec)
    namespace = Config.namespace()

    @client.list(api_version, name, namespace: namespace)
  end

  @spec fetch_resource_version(Impl.t()) :: {:ok, binary} | {:error, binary}
  defp fetch_resource_version(state = %Impl{}) do
    operation = list_operation(state)
    response = @client.run(operation, Config.cluster_name(), params: %{limit: 1})

    case response do
      {:ok, response} ->
        {:ok, extract_rv(response)}

      _ ->
        {:error, "No resource version found for operation: #{inspect(operation)}"}
    end
  end

  def process_lines(state = %Impl{resource_version: rv}, lines) do
    Enum.reduce(lines, {:ok, rv}, fn line, status ->
      case status do
        {:ok, current_rv} ->
          process_line(line, current_rv, state)

        {:error, :gone} ->
          {:error, :gone}
      end
    end)
  end

  def process_line(line, current_rv, state = %Impl{}) do
    %{"type" => type, "object" => raw_object} = Jason.decode!(line)

    case extract_rv(raw_object) do
      {:gone, _message} ->
        {:error, :gone}

      ^current_rv ->
        {:ok, current_rv}

      new_rv ->
        dispatch(%{"type" => type, "object" => raw_object}, state.controller)
        {:ok, new_rv}
    end
  end

  @spec extract_rv(map | binary) :: binary | {:gone, binary()}
  def extract_rv(%{"metadata" => %{"resourceVersion" => rv}}), do: rv
  def extract_rv(%{"message" => message}), do: {:gone, message}

  @spec emit_telemetry_measurement(atom, map, module, map | nil) :: :ok
  defp emit_telemetry_measurement(name, measurement, controller, extra \\ %{}) do
    metadata = CRD.telemetry_metadata(controller.crd_spec, extra)
    Telemetry.emit([:watcher, name], measurement, metadata)
  end
end
