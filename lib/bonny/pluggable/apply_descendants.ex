defmodule Bonny.Pluggable.ApplyDescendants do
  @moduledoc """
  Applies all the descendants added to the `%Bonny.Axn{}` struct.

  ## Options

    * `:events_for_actions` - List of actions for which events will be created
      upon successful apply. Defaults to `[:add, :modify]` (Reconcile actions
      are triggered regularly which would create lots of events for no actions.)

  ## Examples

      step Bonny.Pluggable.ApplyDescendants, events_for_actions: [:add, :modify, :reconcile]
  """

  @behaviour Pluggable

  @impl true
  def init(opts \\ []), do: opts

  @impl true
  def call(axn, opts) do
    events_for_actions = opts[:events_for_actions] || [:add, :modify]
    Bonny.Axn.apply_descendants(axn, create_events: axn.action in events_for_actions)
  end
end
