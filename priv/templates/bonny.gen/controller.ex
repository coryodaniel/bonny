defmodule <%= app_name %>.Controller.<%= controller_name %> do
  @moduledoc """
  <%= app_name %>: <%= controller_name %> controller.

  """
  use Bonny.ControllerV2

  step Bonny.Pluggable.SkipObservedGenerations
  step :handle_event
  step Bonny.Pluggable.SetObservedGeneration

  # apply the resource
  def handle_event(%Bonny.Axn{action: action} = axn, _opts)
      when action in [:add, :modify, :reconcile] do
    IO.inspect(axn.resource)
    success_event(axn)
  end

  # delete the resource
  def handle_event(%Bonny.Axn{action: :delete} = axn, _opts) do
    IO.inspect(axn.resource)
    axn
  end
end
