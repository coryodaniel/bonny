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

  step :send_done

  step Bonny.Pluggable.Finalizer,
    id: "example.com/cleanup",
    impl: &__MODULE__.cleanup/1,
    add_to_resource: &__MODULE__.add_finalizers?/1

  step Bonny.Pluggable.Finalizer,
    id: "example.com/cleanup2",
    impl: &__MODULE__.cleanup2/1,
    add_to_resource: &__MODULE__.add_finalizers?/1,
    log_level: :debug

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
    [to_rbac_rule({"example.com", "testresourcev2s/status", "*"})]
    [to_rbac_rule({"example.com", "whizbangs", "get"})]
  end

  def cleanup(axn) do
    respond(axn.resource, :cleanup)
    {:ok, axn}
  end

  def cleanup2(axn) do
    respond(axn.resource, :cleanup2)
    {:ok, axn}
  end

  def add_finalizers?(axn) do
    axn.resource["metadata"]["annotations"]["add-finalizers"] == "True"
  end

  def send_done(axn, _) do
    Bonny.Axn.register_after_processed(axn, fn %Bonny.Axn{resource: resource} = axn ->
      pid = resource |> get_in(["spec", "pid"]) |> Bonny.Test.ResourceHelper.string_to_pid()
      ref = resource |> get_in(["spec", "ref"]) |> Bonny.Test.ResourceHelper.string_to_ref()
      name = resource |> get_in(["metadata", "name"])

      send(pid, {ref, :done, name})
      axn
    end)
  end
end
