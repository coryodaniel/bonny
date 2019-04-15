defmodule Bonny.Reconciler do
  @moduledoc """
  Requests all of a CRD's resources and invokes `reconcile/1` on the controller module for each resource.
  """

  @client Application.get_env(:bonny, :k8s_client, K8s.Client)
  @frequency Application.get_env(:bonny, :reconcile_every, 5 * 60 * 1000)
  @limit Application.get_env(:bonny, :reconcile_batch_size, 50)

  use GenServer
  require Logger
  alias Bonny.{Config, CRD, Reconciler, Telemetry}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl GenServer
  def init(state) do
    emit_telemetry_event(:genserver_initialized)
    schedule()
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:run, state) do
    emit_telemetry_event(:started)
    Enum.each(Config.controllers(), &Reconciler.run/1)

    schedule()
    {:noreply, state}
  end

  @spec schedule() :: reference
  defp schedule() do
    emit_telemetry_event(:scheduled)
    Process.send_after(self(), :run, @frequency)
  end

  @doc false
  @spec run(module) :: no_return
  def run(controller, limit \\ @limit) do
    get_items(controller, limit, nil)
  end

  @spec get_items(module, integer, nil | :halt | binary) :: no_return
  defp get_items(_controller, _limit, :halt), do: nil

  defp get_items(controller, limit, continue) do
    request = fn -> list_items(controller, limit, continue) end
    {time, response} = Telemetry.measure(request)
    metadata = CRD.telemetry_metadata(controller.crd_spec)

    case response do
      {:ok, body} ->
        measurements = %{item_count: length(body["items"]), duration: time}
        emit_telemetry_measurement(:get_items_succeeded, measurements, metadata)

        reconcile_async(body["items"], controller)
        get_items(controller, limit, do_continue(body))

      {:error, reason} ->
        emit_telemetry_measurement(:get_items_failed, %{duration: time}, metadata)
        Logger.error("Failed reconciling controller: #{controller}, reason: #{reason}")
        {:error, reason}
    end
  end

  @spec reconcile_async(list(map), module) :: list(map)
  defp reconcile_async(items, controller) do
    Enum.each(items, fn item ->
      Task.start(fn -> do_reconcile(controller, item) end)
    end)

    items
  end

  @spec list_items(module, integer, nil | binary) ::
          {:ok, map() | reference()} | {:error, atom()} | {:error, binary()}
  defp list_items(controller, limit, continue) do
    crd_spec = controller.crd_spec
    api_version = CRD.api_version(crd_spec)
    name = CRD.kind(crd_spec)

    operation = @client.list(api_version, name, namespace: Config.namespace())
    params = %{limit: limit, continue: continue}

    @client.run(operation, Config.cluster_name(), params: params)
  end

  @spec do_reconcile(module, map) :: :ok | :error
  defp do_reconcile(controller, item) do
    {time, result} = Telemetry.measure(fn -> controller.reconcile(item) end)

    metadata = CRD.telemetry_metadata(controller.crd_spec)
    measurements = %{duration: time}

    case result do
      :ok ->
        emit_telemetry_measurement(:item_succeeded, measurements, metadata)
        :ok

      :error ->
        emit_telemetry_measurement(:item_failed, measurements, metadata)
        :error
    end
  end

  @spec do_continue(map) :: :halt | binary
  defp do_continue(%{"metadata" => %{"continue" => ""}}), do: :halt
  defp do_continue(%{"metadata" => %{"continue" => cont}}) when is_binary(cont), do: cont
  defp do_continue(_map), do: :halt

  @spec emit_telemetry_event(atom, map | nil) :: :ok
  defp emit_telemetry_event(name, metadata \\ %{}) do
    Telemetry.emit([:reconciler, name], %{}, metadata)
  end

  @spec emit_telemetry_measurement(atom, map, map) :: :ok
  defp emit_telemetry_measurement(name, measurement, metadata) do
    Telemetry.emit([:reconciler, name], measurement, metadata)
  end
end
