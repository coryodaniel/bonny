defmodule Bonny.ControllerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  describe "__using__" do
    test "crd/0 returns the CRD definition" do
      assert Whizbang.crd() == %Bonny.CRD{
               additional_printer_columns: [],
               group: "example.com",
               names: %{
                 kind: "Whizbang",
                 plural: "whizbangs",
                 shortNames: nil,
                 singular: "whizbang"
               },
               scope: :namespaced,
               version: "v1"
             }
    end

    test "sets a default group" do
      crd = Whizbang.crd()
      assert crd.group == "example.com"
    end

    test "allows overriding a group" do
      crd = V3.Whizbang.crd()
      assert crd.group == "kewl.example.io"
    end

    test "defaults the scope to `:namespaced`" do
      assert Whizbang.crd().scope == :namespaced
    end

    test "allows overriding a scope" do
      assert V3.Whizbang.crd().scope == :cluster
    end

    test "derives the kind from the module name" do
      crd = Whizbang.crd()
      kind = crd.names[:kind]
      assert kind == "Whizbang"
    end

    test "allows overriding a kind" do
      crd = V1.Whizbang.crd()
      kind = crd.names[:kind]
      assert kind == "Whizzo"
    end

    test "sets a default version" do
      assert Whizbang.crd().version == "v1"
    end

    test "derives the version from the module name" do
      assert V2.Whizbang.crd().version == "v2"
    end

    test "allows overriding a version" do
      assert V3.Whizbang.crd().version == "v3alpha1"
    end

    test "derives the CRD names from the module" do
      assert Whizbang.crd().names == %{
               plural: "whizbangs",
               singular: "whizbang",
               kind: "Whizbang",
               shortNames: nil
             }
    end

    test "allows overriding the names" do
      assert V2.Whizbang.crd().names == %{
               plural: "bars",
               singular: "qux",
               kind: "Foo",
               shortNames: ["f", "b", "q"]
             }
    end

    test "defaults additional printer columns to nil" do
      assert Whizbang.crd().additional_printer_columns == []
    end

    test "allows additional printer columns to be overridden" do
      assert V3.Whizbang.crd().additional_printer_columns == [
               %{
                 JSONPath: ".spec.test",
                 description: "test",
                 name: "test",
                 type: "string"
               },
               %{
                 JSONPath: ".metadata.creationTimestamp",
                 description:
                   "CreationTimestamp is a timestamp representing the server time when this object was created. It is not guaranteed to be set in happens-before order across separate operations. Clients may not set this value. It is represented in RFC3339 form and is in UTC.\n\n      Populated by the system. Read-only. Null for lists. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata",
                 name: "Age",
                 type: "date"
               }
             ]
    end
  end

  test "builds RBAC rules when set" do
    assert V2.Whizbang.rules() == [
             %{apiGroups: ["apiextensions.k8s.io"], resources: ["bar"], verbs: ["*"]},
             %{apiGroups: ["apiextensions.k8s.io"], resources: ["foo"], verbs: ["*"]}
           ]
  end
end
