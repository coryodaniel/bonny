defmodule Bonny.ControllerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  describe "crd_spec/0" do
    test "without attributes" do
      crd_spec = %Bonny.CRD{
        group: "bonny.test",
        scope: :namespaced,
        version: "v1",
        names: %{
          plural: "whizbangs",
          singular: "whizbang",
          kind: "Whizbang",
          short_names: nil
        }
      }

      assert crd_spec == V1.Whizbang.crd_spec()
    end

    test "with attributes" do
      crd_spec = %Bonny.CRD{
        group: "kewl.example.io",
        scope: :cluster,
        version: "v2alpha1",
        names: %{
          plural: "foos",
          singular: "foo",
          kind: "Foo"
        }
      }

      assert crd_spec == V2.Whizbang.crd_spec()
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
