defmodule Bonny.CRDV2Test do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Bonny.CRD.Version
  alias Bonny.CRDV2, as: MUT

  doctest MUT

  describe "new!/1" do
    test "wraps versions if only one given" do
      crd =
        MUT.new!(
          names: %{singular: "somekind", plural: "somekinds", kind: "SomeKind", shortNames: []},
          group: "example.xom",
          versions: struct!(Version, name: "v1")
        )

      assert is_list(crd.versions)
      assert 1 == length(crd.versions)
    end
  end

  describe "to_manifest" do
    test "creates manifest" do
      crd =
        MUT.new!(
          names: %{singular: "somekind", plural: "somekinds", kind: "SomeKind", shortNames: []},
          group: "example.xom",
          versions: [struct!(Version, name: "v1")],
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
            %Bonny.CRD.Version{
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

  describe "kind_to_names!/2" do
    test "creates names for simple cases correctly" do
      kind = "SomeKind"

      assert %{singular: "somekind", plural: "somekinds", kind: kind, shortNames: []} ==
               MUT.kind_to_names(kind)
    end

    test "creates names for heroes correctly" do
      kind = "Hero"

      assert %{singular: "hero", plural: "heroes", kind: kind, shortNames: []} ==
               MUT.kind_to_names(kind)
    end

    test "adds short names" do
      kind = "SomeKind"
      shorts = ["sk", "some"]

      assert %{singular: "somekind", plural: "somekinds", kind: kind, shortNames: shorts} ==
               MUT.kind_to_names(kind, shorts)
    end
  end
end
