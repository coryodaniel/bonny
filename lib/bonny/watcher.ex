defmodule Test.Bonny.WidgetList do
  defstruct [:api_version, :items, :kind, :metadata]
  @type t :: %Test.Bonny.WidgetList{
    api_version: String.t(),
    items: list(Test.Bonny.Widget.t()),
    kind: String.t(),
    metadata: Kazan.Models.Apimachinery.Meta.V1.ListMeta.t()
  }
end

defmodule Test.Bonny.Widget do
  defstruct [:api_version, :kind, :metadata, :spec, :status]
  @type t :: %Test.Bonny.Widget{
    api_version: String.t(),
    kind: String.t(),
    metadata: Kazan.Models.Apimachinery.Meta.V1.ObjectMeta.t(),
    spec: Test.Bonny.WidgetSpec.t(),
    status: Test.Bonny.WidgetStatus.t()
  }
end

defmodule Test.Bonny.WidgetSpec do
  defstruct [:finalizers]
  @type t :: %Test.Bonny.WidgetSpec{finalizers: String.t()}
end

defmodule Test.Bonny.WidgetStatus do
  defstruct [:phase]
  @type t :: %Test.Bonny.WidgetStatus{phase: String.t()}
end

defmodule Bonny.Watcher do
  require Logger
  use GenServer

  def start_link(opts) do
    Logger.info("Starting watcher")
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

    custom_request = %Kazan.Request{
      method: "get",
      path: "/apis/apiextensions.k8s.io/v1beta1/customresourcedefinitions/widgets.bonny.coryodaniel.com",
      query_params: %{},
      response_schema: Test.Bonny.WidgetList
    }
    Logger.info("Custom Request")
    Logger.info(inspect(custom_request))
    {:ok, _} = Kazan.Watcher.start_link(custom_request, send_to: self())

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
