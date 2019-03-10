defmodule Bonny.Watcher.Impl do
  @moduledoc """
  Implementation logic for `Bonny.Watcher`
  """

  alias Bonny.Watcher.Impl
  require Logger

  @timeout 5 * 60 * 1000
  @type t :: %__MODULE__{
          spec: Bonny.CRD.t(),
          cluster_name: String.t(),
          mod: atom(),
          resource_version: String.t() | nil
        }

  defstruct [:spec, :cluster_name, :mod, :resource_version]

  def new(controller) do
    %__MODULE__{
      cluster_name: Bonny.Config.cluster_name(),
      mod: controller,
      spec: apply(controller, :crd_spec, []),
      resource_version: nil
    }
  end

  @doc """
  Watches a CRD resource for `ADDED`, `MODIFIED`, and `DELETED` events from the Kubernetes API.

  Streams HTTPoison response to `Bonny.Watcher`
  """
  @spec watch_for_changes(Impl.t(), pid()) :: nil
  def watch_for_changes(state = %Impl{}, watcher) do
    group_version = Bonny.CRD.group_version(state.spec)
    name = Bonny.CRD.plural(state.spec)
    namespace = Bonny.Config.namespace()

    operation = K8s.Client.list(group_version, name, namespace: namespace)
    K8s.Client.run(operation, state.cluster_name, stream_to: watcher, recv_timeout: @timeout)
  end

  @doc """
  Dispatches an `ADDED`, `MODIFIED`, and `DELETED` events to an controller
  """
  @spec dispatch(map, atom) :: nil
  def dispatch(%{"type" => "ADDED", "object" => object}, controller),
    do: do_dispatch(controller, :add, object)

  def dispatch(%{"type" => "MODIFIED", "object" => object}, controller),
    do: do_dispatch(controller, :modify, object)

  def dispatch(%{"type" => "DELETED", "object" => object}, controller),
    do: do_dispatch(controller, :delete, object)

  @spec do_dispatch(atom, atom, map) :: nil
  defp do_dispatch(controller, event, object) do
    Logger.info("TODO: Update version; Object: #{inspect(object)}")

    Logger.debug(fn -> "Dispatching: #{inspect(controller)}.#{event}/1" end)

    case apply(controller, event, [object]) do
      :ok ->
        Logger.debug(fn -> "#{inspect(controller)}.#{event}/1 succeeded" end)

      :error ->
        Logger.error(fn -> "#{inspect(controller)}.#{event}/1 failed" end)

      invalid ->
        Logger.error(fn ->
          "Unsupported response from #{inspect(controller)}.#{event}/1: #{inspect(invalid)}"
        end)
    end

    nil
  end

  @doc """
  Receives a plaintext formatted JSON response line from `HTTPoison.AsyncChunk` and parses into a map
  """
  @spec parse_chunk(binary) :: map
  def parse_chunk(line) do
    line
    |> String.trim()
    |> Jason.decode!()
  end
end
