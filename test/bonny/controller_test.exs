defmodule Bonny.ControllerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  describe "crd_spec/0" do
    test "uses the module as the kind when not set" do
      crd_spec = %Bonny.CRD{
        group: "example.com",
        scope: :namespaced,
        version: "v1",
        names: %{
          plural: "whizbangs",
          singular: "whizbang",
          kind: "Whizbang",
          shortNames: nil
        }
      }

      assert crd_spec == Whizbang.crd_spec()
    end

    test "uses defaults when names attribute is not set" do
      crd_spec = %Bonny.CRD{
        group: "example.com",
        scope: :namespaced,
        version: "v1",
        names: %{
          plural: "whizzos",
          singular: "whizzo",
          kind: "Whizzo",
          shortNames: nil
        }
      }

      assert crd_spec == V1.Whizbang.crd_spec()
    end

    test "uses names attribute when set" do
      crd_spec = %Bonny.CRD{
        group: "kewl.example.io",
        scope: :cluster,
        version: "v2alpha1",
        names: %{kind: "Foo", plural: "bars", shortNames: ["f", "b", "q"], singular: "qux"}
      }

      assert crd_spec == V2.Whizbang.crd_spec()
    end

    test "with custom columns" do
      crd_spec = %Bonny.CRD{
        group: "kewl.example.io",
        scope: :cluster,
        version: "v2alpha1",
        names: %{
          plural: "foos",
          singular: "foo",
          kind: "Foo",
          shortNames: nil
        },
        additionalPrinterColumns:
          [
            %{
              name: "test",
              type: "string",
              description: "test",
              JSONPath: ".spec.test"
            }
          ] ++ V3.Whizbang.default_columns()
      }

      assert crd_spec == V3.Whizbang.crd_spec()
    end
  end

  describe "rules/0" do
    test "defines RBAC rules" do
      rules = V2.Whizbang.rules()

      assert rules == [
               %{apiGroups: ["apiextensions.k8s.io"], resources: ["bar"], verbs: ["*"]},
               %{apiGroups: ["apiextensions.k8s.io"], resources: ["foo"], verbs: ["*"]}
             ]
    end
  end
end
