defmodule Bonny.ControllerV2Test do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule FooBar do
    alias Bonny.API.CRD
    alias Bonny.API.Version
    require CRD

    defmodule V1Beta1 do
      use Version

      def manifest(), do: defaults()
    end

    defmodule V1 do
      use Version,
        hub: true

      def manifest() do
        struct!(
          defaults(),
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
          additionalPrinterColumns: [
            %{
              name: "foos",
              type: :integer,
              description: "Number of foos",
              jsonPath: ".spec.foos"
            }
          ]
        )
      end
    end

    use Bonny.ControllerV2,
      for_resource:
        CRD.build_for_controller!(
          group: "test.com",
          scope: :Cluster,
          names: Bonny.API.CRD.kind_to_names("FooBar", ["fb"]),
          versions: [V1, V1Beta1]
        )

    rbac_rule({"", ["secrets"], ["get", "watch", "list"]})

    rbac_rule({"v1", ["pods"], ["get", "watch", "list"]})

    @impl true
    def add(_resource), do: :ok

    @impl true
    def modify(_resource), do: :ok

    @impl true
    def delete(_resource), do: :ok

    @impl true
    def reconcile(_resource), do: :ok
  end

  describe "__using__" do
    test "creates crd/0 with group, scope, names and version" do
      %{spec: crd_spec} = FooBar.crd_manifest()

      assert %{
               group: "test.com",
               scope: :Cluster,
               names: %{
                 singular: "foobar",
                 plural: "foobars",
                 kind: "FooBar",
                 shortNames: ["fb"]
               },
               versions: _
             } = crd_spec

      assert 2 == length(crd_spec.versions)

      # no subresource
      assert %{} == hd(crd_spec.versions).subresources
    end

    test "creates status subresource if skip_observed_generations is true" do
      %{spec: crd_spec} = TestResourceV3.crd_manifest()

      assert %{status: %{}} == hd(crd_spec.versions).subresources

      assert %{
               properties: %{observedGeneration: %{type: :integer}, rand: %{type: :string}},
               type: :object
             } ==
               get_in(crd_spec, [
                 Access.key(:versions),
                 Access.at(0),
                 Access.key(:schema),
                 :openAPIV3Schema,
                 :properties,
                 :status
               ])
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
      assert "foobars" = op.name
      assert :get = op.method
      assert :list = op.verb
    end
  end
end
