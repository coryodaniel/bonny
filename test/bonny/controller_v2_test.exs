defmodule Bonny.ControllerV2Test do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule FooBar do
    alias Bonny.CRD.Version

    use Bonny.ControllerV2,
      rbac_rule: {"", ["secrets"], ["get", "watch", "list"]},
      rbac_rule: {"v1", ["pods"], ["get", "watch", "list"]}

    @impl true
    @spec apply(map()) :: :ok | :error
    def apply(_resource), do: :ok

    @impl true
    @spec delete(map()) :: :ok | :error
    def delete(_resource), do: :ok

    @impl true
    def customize_crd(_) do
      Bonny.CRDV2.new!(
        group: "test.com",
        version: Version.new!(name: "v1beta1", storage: false),
        version:
          Version.new!(
            name: "v1",
            storage: true,
            schema: %{
              openAPIV3Schema: %{
                type: :object,
                properties: %{
                  spec: %{
                    type: :object,
                    properties: %{
                      foos: %{type: :integer},
                      has_bars: %{type: :boolean},
                      description: %{type: :string}
                    }
                  }
                }
              }
            },
            additionalPrinterColumns: %{
              name: "foos",
              type: :integer,
              description: "Number of foos",
              jsonPath: ".spec.foos"
            }
          ),
        scope: :Cluster,
        names: Bonny.CRDV2.kind_to_names("FooBar", ["fb"])
      )
    end
  end

  describe "__using__" do
    test "creates crd/0 with group, scope, names and version" do
      crd = FooBar.crd()

      assert %Bonny.CRDV2{
               group: "test.com",
               scope: :Cluster,
               names: %{singular: "foobar", plural: "foobars", kind: "FooBar", shortNames: ["fb"]},
               versions: _
             } = crd

      assert 2 == length(crd.versions)
    end

    test "creates rules/0 with all rules" do
      rules = FooBar.rules()

      assert is_list(rules)
      assert 2 == length(rules)
    end
  end

  describe "list_operation/1" do
    test "creates the correct list operation for the custom resource" do
      op = FooBar.list_operation()

      assert %K8s.Operation{} = op
      assert "test.com/v1" = op.api_version
      assert "FooBar" = op.name
      assert :get = op.method
      assert :list = op.verb
    end
  end
end
