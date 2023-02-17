defmodule Bonny.Axn do
  @moduledoc """
  Describes a resource action event.

  This is the token passed to all steps of your operator and controller
  pipeline.

  This module gets imported to your controllers where you should use the
  functions `register_descendant/3`, `update_status/2` and the ones to register
  events: `success_event/2`, `failure_event/2` and/or `register_event/6`. Note
  that these functions raise exceptions if those resources have already been
  applied to the cluster.

  The `register_before_*` functions can be used in `Pluggable` steps in order
  to register callbacks that are called before applying resources to the
  cluster. Have a look at `Bonny.Pluggable.Logger` for a use case.

  ## Action event fields

  These fields contain information on the action event that occurred.

    * `action` - the action that triggered this event
    * `resource` - the resource the action was applied to
    * `conn` - the connection to the cluster the event occurred
    * `operator` - the operator that discovered and dispatched the event
    * `controller` - the controller handling the event and its init opts

  ## Reaction fields

    * `descendants` - descending resources defined by the handling controller
    * `status` - the data to be applied to the status subresource
    * `events` - Kubernetes events regarding the resource to be applied to the cluster


  ## Pipeline fields

    * `halted` - the boolean status on whether the pipeline was halted
    * `assigns` - shared user data as a map
    * `private` - shared library data as a map
    * `states` - The states for status, events and descendants

  """

  @derive Pluggable.Token

  alias Bonny.Event
  alias Bonny.Resource

  import Bitwise
  require Logger

  @type assigns :: %{optional(atom) => any}

  @type states :: integer()

  @type t :: %__MODULE__{
          action: :add | :modify | :reconcile | :delete,
          conn: K8s.Conn.t(),
          descendants: list(Resource.t()),
          events: list(Bonny.Event.t()),
          resource: Resource.t(),
          status: map() | nil,
          assigns: assigns(),
          private: assigns(),
          halted: boolean(),
          controller: {controller :: module(), init_opts :: keyword()} | nil,
          operator: module() | nil,
          states: states()
        }

  @enforce_keys [:conn, :resource, :action]
  defstruct [
    :action,
    :conn,
    :resource,
    :controller,
    status: nil,
    assigns: %{},
    private: %{},
    descendants: [],
    events: [],
    halted: false,
    operator: nil,
    states: 0
  ]

  @status_applied 1
  @descendants_applied 1 <<< 1
  @events_emitted 1 <<< 2

  defguard is_status_applied(axn) when (axn.states &&& @status_applied) == @status_applied

  defguard are_descendants_applied(axn)
           when (axn.states &&& @descendants_applied) == @descendants_applied

  defguard are_events_emitted(axn) when (axn.states &&& @events_emitted) == @events_emitted

  @spec new!(Keyword.t()) :: t()
  def new!(fields), do: struct!(__MODULE__, fields)

  defmodule StatusAlreadyAppliedError do
    defexception message: "the status has already been applied"

    @moduledoc """
    Error raised when trying to update or apply an already applied status
    """
  end

  defmodule DescendantsAlreadyAppliedError do
    defexception message: "the descendants have already been applied"

    @moduledoc """
    Error raised when trying to register a descendant or apply the descendants
    when already applied.
    """
  end

  defmodule EventsAlreadyEmittedError do
    defexception message: "the events have already been emitted"

    @moduledoc """
    Error raised when trying to register an event or emit evnts when already
    emitted.
    """
  end

  @doc """
  Registers a Kubernetes event to the `%Axn{}` token to be emitted by Bonny.
  """
  @spec register_event(
          t(),
          Resource.t() | nil,
          Event.event_type(),
          binary(),
          binary(),
          binary()
        ) :: t()
  def register_event(
        axn,
        related \\ nil,
        event_type,
        reason,
        action,
        message
      ) do
    event = Bonny.Event.new!(axn.resource, related, event_type, reason, action, message)
    add_event(axn, event)
  end

  @doc """
  Registers a asuccess event to the `%Axn{}` token to be emitted by Bonny.
  """
  @spec success_event(t(), Keyword.t()) :: t()
  def success_event(axn, opts \\ []) do
    action_string = axn.action |> Atom.to_string() |> String.capitalize()

    event =
      [
        reason: "Successful #{action_string}",
        message: "Resource #{axn.action} was successful."
      ]
      |> Keyword.merge(opts)
      |> Keyword.merge(
        event_type: :Normal,
        regarding: axn.resource,
        action: Atom.to_string(axn.action)
      )
      |> Event.new!()

    add_event(axn, event)
  end

  @doc """
  Registers a failure event to the `%Axn{}` token to be emitted by Bonny.
  """
  @spec failure_event(t(), Keyword.t()) :: t()
  def failure_event(axn, opts \\ []) do
    action_string = axn.action |> Atom.to_string() |> String.capitalize()

    event =
      [
        reason: "Failed #{action_string}",
        message: "Resource #{axn.action} has failed, no reason as specified."
      ]
      |> Keyword.merge(opts)
      |> Keyword.merge(
        event_type: :Warning,
        regarding: axn.resource,
        action: Atom.to_string(axn.action)
      )
      |> Event.new!()

    add_event(axn, event)
  end

  defp add_event(axn, _) when are_events_emitted(axn) do
    raise EventsAlreadyEmittedError
  end

  defp add_event(axn, event), do: %__MODULE__{axn | events: [event | axn.events]}

  @doc """
  Empties the list of events without emitting them.
  """
  @spec clear_events(t()) :: t()
  def clear_events(axn) when are_events_emitted(axn) do
    raise EventsAlreadyEmittedError
  end

  def clear_events(axn), do: %{axn | events: []}

  @doc """
  Registers a decending object to be applied.
  Owner reference will be added automatically.
  Adding the owner reference can be disabled by passing the option
  `omit_owner_ref: true`.
  """
  @spec register_descendant(t(), Resource.t(), Keyword.t()) :: t()
  def register_descendant(axn, descendant, opts \\ [])

  def register_descendant(axn, _, _) when are_descendants_applied(axn) do
    raise DescendantsAlreadyAppliedError
  end

  def register_descendant(axn, descendant, opts) do
    descendant =
      if opts[:omit_owner_ref],
        do: descendant,
        else: Resource.add_owner_reference(descendant, axn.resource)

    %__MODULE__{axn | descendants: [descendant | axn.descendants]}
  end

  @doc """
  Executes `fun` for the resource status and applies the new status
  subresource. This can be called multiple times.

  `fun` should be a function of arity 1. It will be passed the
  current status object and expected to return the updated one.

  If no current status exists, an empty map is passed to `fun`
  """
  @spec update_status(t(), (map() -> map())) :: t()

  def update_status(axn, _) when is_status_applied(axn) do
    raise StatusAlreadyAppliedError
  end

  def update_status(axn, fun) do
    current_status = axn.status || axn.resource["status"] || %{}
    new_status = fun.(current_status)
    struct!(axn, status: new_status)
  end

  @doc """
  Emits the events created for this Axn.
  """

  @spec emit_events(t()) :: t()
  def emit_events(axn) when are_events_emitted(axn) do
    raise EventsAlreadyEmittedError
  end

  def emit_events(%__MODULE__{events: events, conn: conn, operator: operator} = axn) do
    events
    |> List.wrap()
    |> Enum.map(&run_before_emit_event(&1, axn))
    |> Enum.map(fn event -> {Bonny.EventRecorder.emit(event, operator, conn), event} end)
    |> Enum.each(fn
      {{:ok, _}, _} ->
        :ok

      {{:error, error}, event} ->
        id = identifier(axn)
        message = emit_event_error_message(error)

        Logger.error("#{inspect(id)} - #{message}",
          library: :bonny,
          event: event,
          error: error
        )
    end)

    mark_events_emitted(axn)
  end

  @doc """
  Applies the status to the resource's status subresource in the cluster.
  If no status was specified, :noop is returned.
  """
  @spec apply_status(t(), Keyword.t()) :: t()
  def apply_status(axn, apply_opts \\ [])

  def apply_status(axn, _) when is_status_applied(axn) do
    raise StatusAlreadyAppliedError
  end

  def apply_status(%__MODULE__{status: nil} = axn, _) do
    mark_status_applied(axn)
  end

  def apply_status(%Bonny.Axn{resource: resource} = axn, apply_opts) do
    result =
      resource
      |> Map.put("status", axn.status)
      |> run_before_apply_status(axn)
      |> Resource.apply_status(axn.conn, apply_opts)

    case result do
      {:ok, _} ->
        mark_status_applied(axn)

      {:error, error} ->
        id = identifier(axn)
        message = apply_status_error_message(error)

        Logger.error("#{inspect(id)} - #{message}",
          library: :bonny,
          resource: resource,
          error: error
        )

        raise "#{inspect(id)} - #{message}"
    end
  end

  defp apply_error_message(%{message: message}), do: [" ", message]

  defp apply_error_message(_), do: []

  defp apply_status_error_message(%K8s.Discovery.Error{}) do
    [
      "Failed applying resource status.",
      " ",
      "The status subresource for this resource seems to be disabled."
    ]
  end

  defp apply_status_error_message(error) do
    ["Failed applying resource status." | apply_error_message(error)]
  end

  defp apply_descendant_error_message(error, descendant) do
    gvkn = Resource.gvkn(descendant)
    ["Failed applying descending (child) resource #{inspect(gvkn)}." | apply_error_message(error)]
  end

  defp emit_event_error_message(error) do
    ["Failed emitting event." | apply_error_message(error)]
  end

  @doc """
  Applies the dependants to the cluster.
  If `:create_events` is true, will create an event for each successful apply.
  Always creates events upon failed applies.

  ## Options

  `:create_events` - Whether events should be created upon success. Defaults to `true`

  All further options are passed to `K8s.Client.apply/2`
  """
  @spec apply_descendants(t(), Keyword.t()) :: t()
  def apply_descendants(axn, opts \\ [])

  def apply_descendants(axn, _) when are_descendants_applied(axn) do
    raise DescendantsAlreadyAppliedError
  end

  def apply_descendants(axn, opts) do
    {create_events, apply_opts} = Keyword.pop(opts, :create_events, [])
    %__MODULE__{descendants: descendants, conn: conn} = axn

    descendants
    |> List.wrap()
    |> run_before_apply_descendants(axn)
    |> Resource.apply_async(conn, apply_opts)
    |> Enum.reduce(axn, fn
      {_, {:ok, descendant}}, acc ->
        if create_events do
          acc
          |> success_event(
            reason: "Successfully applied descendant",
            message:
              "Successfully applied #{K8s.Resource.FieldAccessors.kind(descendant)} #{K8s.Resource.FieldAccessors.name(descendant)} to the cluster.",
            related: descendant
          )
        else
          acc
        end

      {descendant, {:error, error}}, _acc ->
        id = identifier(axn)
        message = apply_descendant_error_message(error, descendant)

        Logger.error("#{inspect(id)} - #{message}",
          library: :bonny,
          resource: descendant,
          error: error
        )

        raise "#{inspect(id)} - #{message}"
    end)
    |> mark_descendants_applied()
  end

  @doc ~S"""
  Registers a callback to be invoked before a status is applied to the
  status subresource.

  Callbacks are invoked in the reverse order they are defined (callbacks
  defined first are invoked last).

  ## Examples

  To log a message for the status being applied:

      require Logger
      Bonny.Axn.register_before_apply_status(axn, fn resource, axn ->
        Logger.info("Status of the #{resource["kind"]} named #{resource["metadata"]["name"]} is applied to namespace #{resource["metadata"]["namespace"]}")
        resource
      end)
  """
  @spec register_before_apply_status(t(), (Resource.t(), t() -> Resource.t())) :: t()
  def register_before_apply_status(%__MODULE__{private: private} = axn, callback)
      when is_function(callback, 2) do
    %{axn | private: update_in(private[:before_apply_status], &[callback | &1 || []])}
  end

  @doc ~S"""
  Registers a callback to be invoked before descendants are applied to the
  cluster.

  Callbacks are invoked in the reverse order they are defined (callbacks
  defined first are invoked last).

  ## Examples

  To log a message:

      require Logger
      Bonny.Axn.register_before_apply_status(axn, fn descendants, axn ->
        Enum.each(descendants, &Logger.info("Descending #{&1["kind"]} named #{&1["name"]} is applied to namespace #{&1["metadata"]["namespace"]}"))
        descendants
      end)
  """
  @spec register_before_apply_descendants(t(), (list(Resource.t()), t() -> list(Resource.t()))) ::
          t()
  def register_before_apply_descendants(%__MODULE__{private: private} = axn, callback)
      when is_function(callback, 2) do
    %{axn | private: update_in(private[:before_apply_descendants], &[callback | &1 || []])}
  end

  @doc ~S"""
  Registers a callback to be invoked before events are emitted to the
  cluster.

  Callbacks are invoked in the reverse order they are defined (callbacks
  defined first are invoked last).

  ## Examples

  To log a message:

      require Logger
      Bonny.Axn.register_before_apply_status(axn, fn events, axn ->
        Logger.info("Event of type #{event.event_type} is emitted")
        events
      end)
  """
  @spec register_before_emit_event(t(), (Bonny.Event.t(), t() -> Bonny.Event.t())) :: t()
  def register_before_emit_event(%__MODULE__{private: private} = axn, callback)
      when is_function(callback, 2) do
    %{axn | private: update_in(private[:before_emit_event], &[callback | &1 || []])}
  end

  defp run_before_apply_status(resource, %__MODULE__{private: private} = axn) do
    for callback <- private[:before_apply_status] || [], reduce: resource do
      resource -> callback.(resource, axn)
    end
  end

  defp run_before_apply_descendants(descendants, %__MODULE__{private: private} = axn) do
    for callback <- private[:before_apply_descendants] || [], reduce: descendants do
      descendants -> callback.(descendants, axn)
    end
  end

  defp run_before_emit_event(event, %__MODULE__{private: private} = axn) do
    for callback <- private[:before_emit_event] || [], reduce: event do
      event -> callback.(event, axn)
    end
  end

  defp mark_status_applied(axn), do: do_mark_state(axn, @status_applied)
  defp mark_descendants_applied(axn), do: do_mark_state(axn, @descendants_applied)
  defp mark_events_emitted(axn), do: do_mark_state(axn, @events_emitted)

  defp do_mark_state(%__MODULE__{states: states} = axn, bitmask) do
    %{axn | states: states ||| bitmask}
  end

  @doc """
  Returns an identifier of an action event (resource and action) as tuple.
  Can be used in logs and similar.
  """
  @spec identifier(t()) :: {binary(), binary(), binary()}
  def identifier(%__MODULE__{action: action, resource: resource}) do
    {ns_name, api_version, others} = Bonny.Resource.gvkn(resource)
    {ns_name, api_version, "#{others}, Action=#{inspect(action)}"}
  end

  @doc """
  Sets the condition in the resource status.

  The field `.status.conditions`, if configured in the CRD, nolds a list of
  conditions, their `status` with a `message` and two timestamps. On the
  resource this could look something like this (taken from a Pod):

  ```
  kind: Pod
  status:
    conditions:
      - lastTransitionTime: "2019-10-22T16:29:24Z"
        status: "True"
        type: PodScheduled
      - lastTransitionTime: "2019-10-22T16:29:24Z"
        status: "True"
        type: Initialized
      - lastTransitionTime: "2019-10-22T16:29:31Z"
        status: "True"
        type: ContainersReady
      - lastTransitionTime: "2019-10-22T16:29:31Z"
        status: "True"
        type: Ready
  ```
  """
  @spec set_condition(
          axn :: t(),
          type :: binary(),
          status :: boolean(),
          message :: binary() | nil
        ) :: t()
  def set_condition(axn, type, status, message \\ nil) do
    condition_status = if(status, do: "True", else: "False")
    now = DateTime.utc_now()

    condition =
      %{
        "type" => type,
        "status" => condition_status,
        "message" => message,
        "lastHeartbeatTime" => now,
        "lastTransitionTime" => now
      }
      |> Map.filter(&(!is_nil(&1)))

    update_status(axn, fn status ->
      next_conditions =
        status
        |> Map.get("conditions", [])
        |> Map.new(&{&1["type"], &1})
        |> Map.update(type, condition, fn
          %{"status" => ^condition_status} = old_condition ->
            Map.put(condition, "lastTransitionTime", old_condition["lastTransitionTime"])

          _old_condition ->
            condition
        end)
        |> Map.values()

      Map.put(status, "conditions", next_conditions)
    end)
  end
end
