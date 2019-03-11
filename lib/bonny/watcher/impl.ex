defmodule Bonny.Watcher.Impl do
  @moduledoc """
  Implementation logic for `Bonny.Watcher`
  """

  alias Bonny.Watcher.Impl
  require Logger

  @client Application.get_env(:bonny, :k8s_client, K8s.Client)
  @timeout 5 * 60 * 1000
  @type t :: %__MODULE__{
          spec: Bonny.CRD.t(),
          controller: atom(),
          resource_version: String.t() | nil
        }

  defstruct [:spec, :controller, :resource_version]

  def new(controller) do
    %__MODULE__{
      controller: controller,
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
    operation = list_operation(state)

    rv =
      case state.resource_version do
        nil ->
          case current_resource_version(state) do
            {:ok, rv} ->
              rv

            {:error, msg} ->
              Logger.error(fn -> msg end)
          end

        rv ->
          rv
      end

    @client.watch(operation, Bonny.Config.cluster_name(),
      params: %{resourceVersion: rv},
      stream_to: watcher,
      recv_timeout: @timeout
    )
  end

  @doc """
  Set the resource version
  """
  @spec set_resource_version(Impl.t(), map | pos_integer) :: Impl.t()
  def set_resource_version(state = %Impl{}, event = %{}) do
    rv = get_in(event, ["object", "metadata", "resourceVersion"])
    rv_int = String.to_integer(rv)
    set_resource_version(state, rv_int)
  end

  def set_resource_version(state = %Impl{resource_version: previous}, rv)
      when is_nil(previous) or previous < rv do
    Map.put(state, :resource_version, rv)
  end

  def set_resource_version(state = %Impl{}, _), do: state

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

  @spec list_operation(Impl.t()) :: K8s.Operation.t()
  defp list_operation(state = %Impl{}) do
    group_version = Bonny.CRD.group_version(state.spec)
    name = Bonny.CRD.plural(state.spec)
    namespace = Bonny.Config.namespace()

    @client.list(group_version, name, namespace: namespace)
  end

  @spec current_resource_version(Impl.t()) :: {:ok, binary} | {:error, binary}
  defp current_resource_version(state = %Impl{}) do
    operation = list_operation(state)
    response = @client.run(operation, Bonny.Config.cluster_name(), params: %{limit: 1})

    case response do
      {:ok, %{"metadata" => %{"resourceVersion" => rv}}} ->
        {:ok, rv}

      _ ->
        {:error, "No resource version found for operation: #{inspect(operation)}"}
    end
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
