defmodule Bonny.Watcher.Impl do
  @moduledoc """
  Implementation logic for `Bonny.Watcher`
  """

  alias Bonny.Watcher.{Impl, ResponseBuffer}
  require Logger

  @client Application.get_env(:bonny, :k8s_client, K8s.Client)
  @timeout Application.get_env(:bonny, :watch_timeout, 5 * 60 * 1000)
  @type t :: %__MODULE__{
          spec: Bonny.CRD.t(),
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
    Bonny.Telemetry.emit([:watcher, :initialized], %{}, Bonny.CRD.telemetry_metadata(spec))

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
    Bonny.Telemetry.emit([:watcher, :started], %{}, Bonny.CRD.telemetry_metadata(state.spec))

    operation = list_operation(state)
    rv = get_resource_version(state)

    @client.watch(operation, Bonny.Config.cluster_name(),
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
            Logger.error(fn -> msg end)
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
      {time, result} = Bonny.Telemetry.measure(fn -> apply(controller, event, [object]) end)

      was_successful =
        case result do
          :ok ->
            true

          :error ->
            false

          {:error, msg} ->
            Logger.error(fn -> msg end)
            false
        end

      measurements = %{duration: time}

      metadata =
        Bonny.CRD.telemetry_metadata(controller.crd_spec, %{event: event, success: was_successful})

      Bonny.Telemetry.emit([:watcher, :dispatched], measurements, metadata)
    end)
  end

  @spec list_operation(Impl.t()) :: K8s.Operation.t()
  defp list_operation(state = %Impl{}) do
    api_version = Bonny.CRD.api_version(state.spec)
    name = Bonny.CRD.kind(state.spec)
    namespace = Bonny.Config.namespace()

    @client.list(api_version, name, namespace: namespace)
  end

  @spec fetch_resource_version(Impl.t()) :: {:ok, binary} | {:error, binary}
  defp fetch_resource_version(state = %Impl{}) do
    operation = list_operation(state)
    response = @client.run(operation, Bonny.Config.cluster_name(), params: %{limit: 1})

    case response do
      {:ok, response} ->
        {:ok, extract_rv(response)}

      _ ->
        {:error, "No resource version found for operation: #{inspect(operation)}"}
    end
  end

  @spec extract_rv(map | binary) :: binary | {:gone, binary()}
  def extract_rv(%{"metadata" => %{"resourceVersion" => rv}}), do: rv
  def extract_rv(%{"message" => message}), do: {:gone, message}
end
