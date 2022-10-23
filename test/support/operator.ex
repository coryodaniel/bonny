defmodule Bonny.Test.Operator do
  @moduledoc false
  use Bonny.Operator, default_watch_namespace: "default"

  step(:delegate_to_controller)
  step(Bonny.Pluggable.ApplyStatus)

  def controllers(watching_namespace, _opts) do
    [
      %{
        query: K8s.Client.list("example.com/v1", "TestResourceV2", namespace: watching_namespace),
        controller: TestResourceV2Controller
      }
    ]
  end

  def crds() do
    [
      %Bonny.API.CRD{
        group: "example.com",
        scope: :Namespaced,
        names: Bonny.API.CRD.kind_to_names("TestResourceV2"),
        versions: [Bonny.Test.API.V1.TestResourceV2]
      }
    ]
  end
end
