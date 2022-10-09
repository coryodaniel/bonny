defmodule Bonny.Event do
  @moduledoc """
  Represents a kubernetes event.
  Documentation: https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/
  """
  alias Bonny.Resource

  @typedoc """
  See https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/ for field explanations.
  """
  @type t :: %__MODULE__{
          action: binary(),
          event_type: event_type(),
          message: binary(),
          now: DateTime.t(),
          reason: binary(),
          regarding: map(),
          related: map(),
          reporting_controller: binary(),
          reporting_instance: binary()
        }

  @typedoc """
  Kubernetes events currently support these types.
  """
  @type event_type :: :Normal | :Warning

  @enforce_keys [
    :action,
    :event_type,
    :message,
    :now,
    :reason,
    :regarding,
    :reporting_controller,
    :reporting_instance
  ]

  defstruct [
    :action,
    :event_type,
    :message,
    :now,
    :reason,
    :regarding,
    :related,
    :reporting_controller,
    :reporting_instance
  ]

  @doc """
  Creates an event.

  Options: `:reporting_controller`, `:reporting_instance`
  """
  @spec new!(Keyword.t()) :: t()
  def new!(fields) do
    fields =
      fields
      |> Keyword.update!(:regarding, &Bonny.Resource.resource_reference/1)
      |> Keyword.update(:related, nil, &Bonny.Resource.resource_reference/1)
      |> Keyword.put_new(:now, DateTime.utc_now())
      |> Keyword.put_new(:reporting_controller, Bonny.Config.name())
      |> Keyword.put_new(:reporting_instance, Bonny.Config.instance_name())

    struct!(__MODULE__, fields)
  end

  @spec new!(
          Resource.t(),
          Resource.t() | nil,
          event_type(),
          binary(),
          binary(),
          binary(),
          Keyword.t()
        ) :: t()
  def new!(regarding, related \\ nil, event_type, reason, action, message, opts \\ []) do
    opts
    |> Keyword.merge(
      action: action,
      event_type: event_type,
      message: message,
      reason: reason,
      regarding: regarding,
      related: related
    )
    |> new!()
  end
end
