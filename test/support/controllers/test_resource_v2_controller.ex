defmodule TestResourceV2Controller do
  @moduledoc """
  This controller gets the pid and reference from the resource's spec.
  It then sends a message including that reference, the action and the resource
  name to the pid from the resource.

  A test can therefore create a resource with its own pid (self()), send it
  to kubernetes and wait to receive the message from this controller.
  """

  alias Bonny.API.CRD
  require CRD

  use Bonny.ControllerV2

  step Bonny.Pluggable.SkipObservedGenerations
  step :handle_action

  def handle_action(axn, _opts) do
    respond(axn.resource, axn.action)

    success_event(axn)
  end

  defp respond(resource, action) do
    pid = resource |> get_in(["spec", "pid"]) |> Bonny.Test.ResourceHelper.string_to_pid()
    ref = resource |> get_in(["spec", "ref"]) |> Bonny.Test.ResourceHelper.string_to_ref()
    name = resource |> get_in(["metadata", "name"])

    send(pid, {ref, action, name})
    :ok
  end

  def rbac_rules() do
    [
      to_rbac_rule({"example.com/v1", "testresourcev2s/status", "*"})
    ]
  end
end
