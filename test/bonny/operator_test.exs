defmodule Bonny.OperatorTest do
  use ExUnit.Case, async: true
  alias Bonny.Operator

  test "cluster_role/0" do
    manifest = Operator.cluster_role()

    assert manifest == %{
             apiVersion: "rbac.authorization.k8s.io/v1",
             kind: "ClusterRole",
             metadata: %{name: "bonny", labels: %{bonny: "0.1.0"}},
             rules: [
               %{apiGroups: ["apps"], resources: ["deployments", "services"], verbs: ["*"]},
               %{apiGroups: [""], resources: ["configmaps"], verbs: ["create", "read"]}
             ]
           }
  end

  test "service_account/1" do
    manifest = Operator.service_account("default")

    assert manifest == %{
             metadata: %{name: "bonny", labels: %{bonny: "0.1.0"}, namespace: "default"},
             apiVersion: "v1",
             kind: "ServiceAccount"
           }
  end

  test "crds/0" do
    manifest = Operator.crds()

    assert manifest == [
             %{
               apiVersion: "apiextensions.k8s.io/v1beta1",
               kind: "CustomResourceDefinition",
               metadata: %{
                 labels: %{bonny: "0.1.0"},
                 name: "widgets.bonny.example.io"
               },
               spec: %Bonny.CRD{
                 group: "bonny.example.io",
                 names: %{
                   kind: "Widget",
                   plural: "widgets",
                   short_names: nil,
                   singular: "widget"
                 },
                 scope: "Namespaced",
                 version: "v1"
               }
             },
             %{
               apiVersion: "apiextensions.k8s.io/v1beta1",
               kind: "CustomResourceDefinition",
               metadata: %{
                 labels: %{bonny: "0.1.0"},
                 name: "cogs.bonny.example.io"
               },
               spec: %Bonny.CRD{
                 group: "bonny.example.io",
                 names: %{
                   kind: "Cog",
                   plural: "cogs",
                   short_names: nil,
                   singular: "cog"
                 },
                 scope: "Namespaced",
                 version: "v1"
               }
             }
           ]
  end

  test "cluster_role_binding/1" do
    manifest = Operator.cluster_role_binding("default")

    assert manifest == %{
             apiVersion: "rbac.authorization.k8s.io/v1",
             kind: "ClusterRoleBinding",
             metadata: %{name: "bonny", labels: %{bonny: "0.1.0"}},
             roleRef: %{apiGroup: "rbac.authorization.k8s.io", kind: "ClusterRole", name: "bonny"},
             subjects: [%{kind: "ServiceAccount", name: "bonny", namespace: "default"}]
           }
  end
end
