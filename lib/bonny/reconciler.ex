defmodule Bonny.Reconciler do
  @moduledoc """
  Requests all of a CRD's resources and invokes `reconcile/1` on the controller module for each resource.
  """
  @client Application.get_env(:bonny, :k8s_client, K8s.Client)
  @frequency Application.get_env(:bonny, :reconcile_every, 5 * 60 * 1000)
  @limit Application.get_env(:bonny, :reconcile_batch_size, 50)

  use GenServer
  require Logger
  alias Bonny.{Config, CRD, Reconciler}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl GenServer
  def init(state) do
    schedule()
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:run, state) do
    Logger.debug("Starting reconciliation")
    Enum.each(Config.controllers(), &Reconciler.run/1)

    schedule()
    {:noreply, state}
  end

  defp schedule() do
    Logger.debug("Scheduling reconciler")
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
    crd_spec = controller.crd_spec
    api_version = CRD.api_version(crd_spec)
    name = CRD.kind(crd_spec)

    operation = @client.list(api_version, name, namespace: Config.namespace())
    params = %{limit: limit, continue: continue}
    response = @client.run(operation, Config.cluster_name(), params: params)

    case response do
      {:ok, body} ->
        Enum.each(body["items"], fn item ->
          Task.start(fn -> do_reconcile(controller, item) end)
        end)

        get_items(controller, limit, do_continue(body))

      {:error, reason} ->
        Logger.error(fn -> "Failed reconciling controller: #{controller}, reason: #{reason}" end)
        {:error, reason}
    end
  end

  @spec do_reconcile(module, map) :: :ok | :error | {:error, binary}
  defp do_reconcile(controller, item) do
    {time, result} = Bonny.Telemetry.measure(fn -> controller.reconcile(item) end)

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

    metadata = CRD.telemetry_metadata(controller.crd_spec, %{success: was_successful})
    Bonny.Telemetry.emit([:reconciler, :reconciled], %{duration: time}, metadata)

    result
  end

  @spec do_continue(map) :: :halt | binary
  defp do_continue(%{"metadata" => %{"continue" => ""}}), do: :halt
  defp do_continue(%{"metadata" => %{"continue" => cont}}) when is_binary(cont), do: cont
  defp do_continue(_map), do: :halt
end
