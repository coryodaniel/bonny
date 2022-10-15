defmodule Bonny.Axn do
  @derive Pluggable.Token

  alias Bonny.Event
  alias Bonny.Resource

  @type t :: %__MODULE__{
          action: atom(),
          conn: K8s.Conn.t(),
          decendants: list(Resource.t()),
          events: list(Bonny.Event.t()),
          resource: Resource.t(),
          status: map() | nil,
          assigns: map(),
          halted: boolean()
        }

  @enforce_keys [:conn, :resource, :action]
  defstruct [
    :action,
    :conn,
    :resource,
    :status,
    assigns: %{},
    decendants: [],
    events: [],
    halted: false
  ]

  @spec new!(Keyword.t()) :: t()
  def new!(fields), do: struct!(__MODULE__, fields)

  @spec new!(K8s.Conn.t(), atom(), Resource.t(), Keyword.t()) :: t()
  def new!(conn, action, resource, fields \\ []) do
    fields
    |> Keyword.merge(conn: conn, action: action, resource: resource)
    |> new!()
  end

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
  Instructs bonny to apply a decending object.
  Owner reference will be added automatically.
  Adding the owner reference can be disabled by passing the option
  `ommit_owner_ref: true`.
  """
  @spec apply_decendant(t(), Resource.t(), Keyword.t()) :: t()
  def apply_decendant(axn, decendant, opts \\ []) do
    decendant =
      if opts[:ommit_owner_ref],
        do: decendant,
        else: Resource.add_owner_reference(decendant, axn.resource)

    %__MODULE__{axn | decendants: [decendant | axn.decendants]}
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
end
