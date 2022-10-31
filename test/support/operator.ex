defmodule Bonny.Test.Operator do
  @moduledoc false
  use Bonny.Operator, default_watch_namespace: "default"

  step :delegate_to_controller
  step Bonny.Pluggable.ApplyStatus
  step :send_done

  @impl Bonny.Operator
  def controllers(watching_namespace, _opts) do
    [
      %{
        query: K8s.Client.list("example.com/v1", "TestResourceV2", namespace: watching_namespace),
        controller: TestResourceV2Controller
      }
    ]
  end

  @impl Bonny.Operator
  def crds() do
    [
      %Bonny.API.CRD{
        group: "example.com",
        scope: :Namespaced,
        names: Bonny.API.CRD.kind_to_names("TestResourceV2"),
        versions: [Bonny.Test.API.V1.TestResourceV2]
      },
      %Bonny.API.CRD{
        group: "example.com",
        scope: :Namespaced,
        names: Bonny.API.CRD.kind_to_names("TestResourceV3"),
        versions: [Bonny.Test.API.V1.TestResourceV2]
      }
    ]
  end

  def send_done(%Bonny.Axn{resource: resource} = axn, _) do
    pid = resource |> get_in(["spec", "pid"]) |> Bonny.Test.ResourceHelper.string_to_pid()
    ref = resource |> get_in(["spec", "ref"]) |> Bonny.Test.ResourceHelper.string_to_ref()
    name = resource |> get_in(["metadata", "name"])

    send(pid, {ref, :done, name})
    axn
  end
end
