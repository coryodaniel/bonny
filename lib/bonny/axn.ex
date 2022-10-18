defmodule Bonny.Axn do
  @moduledoc """
  Describes a resource event action.

  This is the token passed to all steps of your operator and controller
  pipeline.
  """

  @derive Pluggable.Token

  alias Bonny.Event
  alias Bonny.Resource

  @type t :: %__MODULE__{
          action: atom(),
          conn: K8s.Conn.t(),
          descendants: list(Resource.t()),
          events: list(Bonny.Event.t()),
          resource: Resource.t(),
          status: map() | nil,
          assigns: map(),
          halted: boolean(),
          handler: atom(),
          operator: atom() | nil
        }

  @enforce_keys [:conn, :resource, :action]
  defstruct [
    :action,
    :conn,
    :resource,
    :status,
    :handler,
    assigns: %{},
    descendants: [],
    events: [],
    halted: false,
    operator: nil
  ]

  @spec new!(Keyword.t()) :: t()
  def new!(fields), do: struct!(__MODULE__, fields)

  @spec event(
          t(),
          Resource.t() | nil,
          Event.event_type(),
          binary(),
          binary(),
          binary()
        ) :: t()
  def event(
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
  Adds a asuccess event to the `%Axn{}` token to be emmitted by Bonny.
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
  Adds a failure event to the `%Axn{}` token to be emmitted by Bonny.
  """
  @spec failed_event(t(), Keyword.t()) :: t()
  def failed_event(axn, opts \\ []) do
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

  defp add_event(axn, event), do: %__MODULE__{axn | events: [event | axn.events]}

  @doc """
  Empties the list of events without emitting them.
  """
  @spec clear_events(t()) :: t()
  def clear_events(axn), do: %{axn | events: []}

  @doc """
  Adds a decending object to be applied.
  Owner reference will be added automatically.
  Adding the owner reference can be disabled by passing the option
  `ommit_owner_ref: true`.
  """
  @spec add_descendant(t(), Resource.t(), Keyword.t()) :: t()
  def add_descendant(axn, descendant, opts \\ []) do
    descendant =
      if opts[:ommit_owner_ref],
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
  def update_status(axn, fun) do
    current_status = axn.status || axn.resource["status"] || %{}
    new_status = fun.(current_status)
    struct!(axn, status: new_status)
  end

  @doc """
  Emits the events created for this Axn.
  """
  @spec emit_events(t()) :: :ok
  def emit_events(%__MODULE__{events: events, conn: conn, operator: operator}) do
    events
    |> List.wrap()
    |> Enum.each(&Bonny.EventRecorder.emit(&1, operator, conn))
  end

  @doc """
  Applies the status to the resource's status subresource in the cluster.
  If no status was specified, :noop is returned.
  """
  @spec apply_status(t(), Keyword.t()) :: K8s.Client.Runner.Base.result_t() | :noop
  def apply_status(axn, apply_opts \\ [])

  def apply_status(%__MODULE__{status: nil}, _), do: :noop

  def apply_status(%__MODULE__{resource: resource, conn: conn, status: status}, apply_opts) do
    dbg(status)

    resource
    |> Map.put("status", status)
    |> Resource.apply_status(conn, apply_opts)
  end

  @doc """
  Applies the dependants to the cluster.
  If `:create_events` is true, will create an event for each successful apply.
  Always creates events upon failed applies.

  ## Options

  `:create_events` - Whether events should be created upon success. Defaults to `true`

  All further options are passed to `K8s.Client.apply/2`
  """
  @spec apply_descendants(t(), Keyword.t()) :: list(K8s.Client.Runner.Base.result_t())
  def apply_descendants(axn, opts \\ []) do
    {create_events, apply_opts} = Keyword.pop(opts, :create_events, [])
    %__MODULE__{descendants: descendants, conn: conn} = axn

    descendants
    |> List.wrap()
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

      {descendant, {:error, _}}, acc ->
        acc
        |> clear_events()
        |> failed_event(
          reason: "Applying descendant failed",
          message:
            "Failed to apply #{K8s.Resource.FieldAccessors.kind(descendant)} #{K8s.Resource.FieldAccessors.name(descendant)} to the cluster."
        )
    end)
  end
end
