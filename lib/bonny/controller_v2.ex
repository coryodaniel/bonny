defmodule Bonny.ControllerV2 do
  @moduledoc """
  `Bonny.ControllerV2` defines controller behaviours and generates boilerplate
  for generating Kubernetes manifests.

  > A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

  Controllers allow for simple `add`, `modify`, `delete`, and `reconcile`
  handling of custom resources in the Kubernetes API.

  This version of the controller lets you customize the resulting CRD before
  you generate your manifest using `mix bonny.gen.manifest`.
  """

  alias Bonny.CRDV2, as: CRD

  @type action :: Bonny.Server.Watcher.action() | :reconcile
  @type event_handler_result_type :: :ok | :error
  @type event_handler_result ::
          event_handler_result_type()
          | {event_handler_result_type(), binary() | nil}
          | {event_handler_result_type(), binary() | nil, Bonny.Resource.t()}
          | {event_handler_result_type(), Bonny.Resource.t()}
  @type watch_or_reconcile_event ::
          Bonny.Server.Watcher.watch_event() | {:reconcile, Bonny.Resource.t()}

  @doc """
  Should return an operation to list resources for watching and reconciliation.

  Bonny.ControllerV2 comes with a default implementation which can be
  overridden by the using module.
  """
  @callback list_operation() :: K8s.Operation.t()

  @doc """
  Bonny.ControllerV2 comes with a default implementation which returns Bonny.Config.config()
  """
  @callback conn() :: K8s.Conn.t()

  @doc """
  Bonny auto-generates a CRD for every controller. Use this (optional) callback to
  override that CRD. You can use it to add versions, specify the OpenAPIV3Schema for them,
  change the resource's scope, and more.
  """
  @callback customize_crd(Bonny.CRDV2.t()) :: Bonny.CRDV2.t()

  #  Action Callbacks
  @callback add(map()) :: event_handler_result_type()
  @callback modify(map()) :: event_handler_result_type()
  @callback delete(map()) :: event_handler_result_type()
  @callback reconcile(map()) :: event_handler_result_type()

  @optional_callbacks customize_crd: 1

  @doc false
  defmacro __using__(opts) do
    quote do
      unquote(__prelude__())
      unquote(__init_process__())
      unquote(__maybes__(opts[:skip_observed_generations]))
      unquote(__defs__())

      defoverridable list_operation: 0, conn: 0
    end
  end

  @spec __prelude__ ::
          {:__block__, [], [{:@ | :import | :use | {any, any, any}, list, [...]}, ...]}
  def __prelude__() do
    quote do
      Module.register_attribute(__MODULE__, :rbac_rules, accumulate: true)

      use Supervisor

      import Bonny.Resource, only: [add_owner_reference: 2]
      import Bonny.ControllerV2, only: [event: 5, event: 6, rbac_rule: 1]

      @behaviour Bonny.ControllerV2

      @before_compile Bonny.ControllerV2
    end
  end

  def __init_process__() do
    quote do
      @spec start_link(term) :: {:ok, pid}
      def start_link(_), do: Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)

      @impl true
      def init(_init_arg), do: Bonny.ControllerV2.__init__(__MODULE__)
    end
  end

  def __init__(controller) do
    conn = controller.conn()
    list_operation = controller.list_operation()

    watcher_stream =
      Bonny.Server.Watcher.get_raw_stream(conn, list_operation)
      |> controller.maybe_reject_watch_event()
      |> Stream.map(&__handle_event__(controller, &1))

    reconciler_stream =
      controller
      |> Bonny.Server.Reconciler.get_stream(conn, list_operation)
      |> Task.async_stream(&__handle_event__(controller, {:reconcile, &1}))

    children = [
      {Bonny.Server.AsyncStreamRunner,
       id: :"#{controller}.WatchServer",
       name: :"#{controller}.WatchServer",
       stream: watcher_stream,
       termination_delay: 5_000},
      {Bonny.Server.AsyncStreamRunner,
       id: :"#{controller}.ReconcileServer",
       name: :"#{controller}.ReconcileServer",
       stream: reconciler_stream,
       termination_delay: 30_000},
      {Bonny.EventRecorder, name: :"#{controller}.EventRecorder", conn: conn}
    ]

    Supervisor.init(
      children,
      strategy: :one_for_one,
      max_restarts: 20,
      max_seconds: 120
    )
  end

  def __maybes__(true) do
    quote do
      defdelegate maybe_set_observed_generation(resource),
        to: Bonny.Resource,
        as: :set_observed_generation

      defdelegate maybe_add_obseved_generation_status(crd),
        to: Bonny.ControllerV2,
        as: :__add_obseved_generation_status__

      defdelegate maybe_reject_watch_event(stream),
        to: Bonny.ControllerV2,
        as: :__reject_watch_event__
    end
  end

  def __maybes__(_) do
    quote do
      def maybe_set_observed_generation(resource), do: resource
      def maybe_add_obseved_generation_status(crd), do: crd
      def maybe_reject_watch_event(stream), do: stream
    end
  end

  def __defs__() do
    quote do
      @impl Bonny.ControllerV2
      def list_operation(), do: Bonny.ControllerV2.list_operation(__MODULE__)

      @impl Bonny.ControllerV2
      defdelegate conn(), to: Bonny.Config

      def crd() do
        __MODULE__
        |> Bonny.ControllerV2.crd()
        |> maybe_add_obseved_generation_status()
      end
    end
  end

  @spec __handle_event__(module(), {atom(), Bonny.Resource.t()}) :: :ok
  def __handle_event__(controller, {action, resource} = watch_event) do
    apply(controller, action, [resource])
    |> map_event_handler_result(watch_event)
    |> process_event_handler_result(controller)
    |> post_process_resource(controller)
  end

  def __add_obseved_generation_status__(crd) do
    Bonny.CRDV2.update_versions(
      crd,
      & &1.storage,
      &Bonny.CRD.Version.add_observed_generation_status/1
    )
  end

  def __reject_watch_event__(stream) do
    Stream.reject(stream, fn
      {:delete, _} ->
        false

      {_, resource} ->
        # skip resource if generation has been observed
        get_in(resource, ~w(metadata generation)) ==
          get_in(resource, [Access.key("status", %{}), "observedGeneration"])
    end)
  end

  @doc """
  Creates a kubernetes event.

  * **regarding**: regarding contains the object this Event is about.
    In most cases it's an Object reporting controller implements,
    e.g. ReplicaSetController implements ReplicaSets and this event
    is emitted because it acts on some changes in a ReplicaSet object.
  * **related**: the related related is the optional secondary object for
    more complex actions. E.g. when regarding object triggers a creation
    or deletion of related object.
  * **event_type**: `:Normal` or `:Warning`
  * **reason**: reason is why the action was taken. It is human-readable.
    This field cannot be empty for new Events and it can have at most
    128 characters.
    e.g "SuccessfulResourceCreation"
  * **action**: e.g. "Add"
  * **message**: note is a human-readable description of the status of this operation
  """
  defmacro event(regarding, related \\ nil, event_type, reason, action, message) do
    quote do
      Bonny.EventRecorder.event(
        __MODULE__.EventRecorder,
        unquote(regarding),
        unquote(related),
        unquote(event_type),
        unquote(reason),
        unquote(action),
        unquote(message)
      )
    end
  end

  @doc """
  Register a RBAC rule. Use this macro if your controller requires
  additional access to the kubernetes API.
  """
  defmacro rbac_rule(rule) do
    quote do
      unquote(Bonny.ControllerV2.__rbac_rule__(rule))
    end
  end

  def __rbac_rule__(rule) do
    quote bind_quoted: [rule: rule] do
      {apis, resources, verbs} = rule

      rule =
        %{
          apiGroups: List.wrap(apis),
          resources: resources,
          verbs: verbs
        }
        |> Macro.escape()

      Module.put_attribute(__MODULE__, :rbac_rules, rule)
    end
  end

  defmacro __before_compile__(%{module: module}) do
    rbac_rules = module |> Module.get_attribute(:rbac_rules, [])

    quote do
      @spec rules() :: list(map())
      def rules(), do: unquote(rbac_rules)
    end
  end

  @spec crd(module()) :: Bonny.CRDV2.t()
  def crd(controller) do
    names =
      controller
      |> Atom.to_string()
      |> String.split(".")
      |> Enum.reverse()
      |> hd()
      |> CRD.kind_to_names()

    CRD.new!(
      names: names,
      group: Bonny.Config.group(),
      version: Bonny.CRD.Version.new!(name: "v1")
    )
    |> maybe_cutomize_crd(controller)
    |> controller.maybe_add_obseved_generation_status()
  end

  defp maybe_cutomize_crd(crd, controller) do
    if function_exported?(controller, :customize_crd, 1),
      do: controller.customize_crd(crd),
      else: crd
  end

  @spec list_operation(module()) :: K8s.Operation.t()
  def list_operation(controller) do
    crd = controller.crd()
    api_version = CRD.resource_api_version(crd)
    kind = crd.names.kind

    case crd.scope do
      :Namespaced -> K8s.Client.list(api_version, kind, namespace: Bonny.Config.namespace())
      _ -> K8s.Client.list(api_version, kind)
    end
  end

  defp map_event_handler_result(type, watch_or_reconcile_event) when type in [:ok, :error],
    do: map_event_handler_result({type, nil}, watch_or_reconcile_event)

  defp map_event_handler_result({type, %{} = resource}, watch_or_reconcile_event),
    do: map_event_handler_result({type, nil, resource}, watch_or_reconcile_event)

  defp map_event_handler_result({type, message}, {action, original_resource}),
    do: {type, message, action, original_resource}

  defp map_event_handler_result({type, message, resource}, {action, original_resource}) do
    if Map.get(resource, "apiVersion") == original_resource["apiVersion"] &&
         Map.get(resource, "kind") == original_resource["kind"],
       do: {type, message, action, resource},
       else: {type, message, action, original_resource}
  end

  defp map_event_handler_result(_, {action, original_resource}) do
    {:ok, nil, action, original_resource}
  end

  defp process_event_handler_result({:ok, message, action, resource}, controller)
       when action in [:add, :modify, :delete] do
    action_string = action |> Atom.to_string() |> String.capitalize()

    Bonny.EventRecorder.event(
      :"#{controller}.EventRecorder",
      resource,
      nil,
      :Normal,
      "Successful" <> action_string,
      Atom.to_string(action),
      message || "Resource #{action} was successful."
    )

    resource
  end

  defp process_event_handler_result({_, message, action, resource}, controller)
       when action in [:add, :modify, :delete] do
    action_string = action |> Atom.to_string() |> String.capitalize()

    Bonny.EventRecorder.event(
      :"#{controller}.EventRecorder",
      resource,
      nil,
      :Normal,
      "Successful" <> action_string,
      Atom.to_string(action),
      message || "Resource #{action} failed."
    )

    resource
  end

  defp process_event_handler_result({_, _, _, resource}, _), do: resource

  defp post_process_resource(resource, controller) do
    crd = controller.crd()
    conn = controller.conn()

    resource
    |> controller.maybe_set_observed_generation()
    |> Bonny.Resource.apply_status(crd.names.plural, conn)

    :ok
  end
end
