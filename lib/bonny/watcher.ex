defmodule Bonny.Watcher do
  require Logger
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    ns_request = Kazan.Apis.Core.V1.list_namespace!()
    Logger.info("NS Request")
    Logger.info(inspect(ns_request))
    {:ok, _} = Kazan.Watcher.start_link(ns_request, send_to: self())

    crd_request = Kazan.Apis.Apiextensions.V1beta1.list_custom_resource_definition!()
    Logger.info("CRD Request")
    Logger.info(inspect(crd_request))
    {:ok, _} = Kazan.Watcher.start_link(crd_request, send_to: self())

    {:ok, %{}}
  end


  def handle_info(%Kazan.Watcher.Event{object: object, from: watcher_pid, type: type}, state) do
    Logger.info("Event received:")
    Logger.info(type)
    Logger.info(inspect(object))

    # case object do
    #   %Kazan.Apis.Core.V1.Namespace{} = namespace ->
    #     process_namespace_event(type, namespace)

    #   %Kazan.Apis.Batch.V1.Job{} = job ->
    #     process_job_event(type, job)
    # end
    {:noreply, state}
  end
end
