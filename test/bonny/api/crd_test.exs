defmodule Bonny.API.CRDTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Bonny.API.CRD, as: MUT
  alias Bonny.API.Version

  defmodule V1 do
    use Version,
      hub: true

    def manifest(), do: defaults()
  end

  doctest MUT

  describe "to_manifest" do
    test "creates manifest" do
      crd =
        MUT.new!(
          names: %{singular: "somekind", plural: "somekinds", kind: "SomeKind", shortNames: []},
          group: "example.xom",
          versions: [V1],
          scope: :Namespaced
        )

      expected = %{
        apiVersion: "apiextensions.k8s.io/v1",
        kind: "CustomResourceDefinition",
        metadata: %{labels: %{"k8s-app" => "bonny"}, name: "somekinds.example.xom"},
        spec: %{
          group: "example.xom",
          names: %{kind: "SomeKind", plural: "somekinds", shortNames: [], singular: "somekind"},
          scope: :Namespaced,
          versions: [
            %Bonny.API.Version{
              name: "v1",
              served: true,
              storage: true,
              deprecated: false,
              deprecationWarning: nil,
              schema: %{
                openAPIV3Schema: %{type: :object, "x-kubernetes-preserve-unknown-fields": true}
              },
              additionalPrinterColumns: []
            }
          ]
        }
      }

      actual = MUT.to_manifest(crd)
      assert expected == actual
    end
  end
end
