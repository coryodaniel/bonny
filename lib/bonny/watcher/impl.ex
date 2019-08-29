defmodule Bonny.Watcher.Impl do
  @moduledoc """
  Implementation logic for `Bonny.Watcher`
  """

  alias Bonny.Watcher.{Impl}
  alias Bonny.Server.Watcher.ResponseBuffer
  alias Bonny.{Config, CRD}
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
  def watch_for_changes(%Impl{} = state, watcher) do
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
  def get_resource_version(%Impl{} = state) do
    case state.resource_version do
      nil ->
        resp = Bonny.Server.Watcher.ResourceVersion.get(list_operation(state))

        case resp do
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

  @spec list_operation(Impl.t()) :: K8s.Operation.t()
  defp list_operation(%Impl{} = state) do
    api_version = CRD.api_version(state.spec)
    name = CRD.kind(state.spec)
    namespace = Config.namespace()

    case state.spec.scope do
      :namespaced -> @client.list(api_version, name, namespace: namespace)
      _ -> @client.list(api_version, name)
    end
  end
end
