defmodule Bonny.OperatorTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Operator

  test "cluster_role/0" do
    manifest = Operator.cluster_role()

    expected = %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRole",
      metadata: %{name: "bonny", labels: %{"k8s-app" => "bonny"}},
      rules: [
        %{
          apiGroups: ["apiextensions.k8s.io"],
          resources: ["customresourcedefinitions"],
          verbs: ["*"]
        },
        %{apiGroups: ["bonny.test"], resources: ["widgets", "cogs"], verbs: ["*"]},
        %{apiGroups: ["apps"], resources: ["deployments", "services"], verbs: ["*"]},
        %{apiGroups: [""], resources: ["configmaps"], verbs: ["create", "read"]}
      ]
    }

    assert manifest == expected
  end

  test "rules/0" do
    manifest = Operator.rules()

    expected = [
      %{
        apiGroups: ["apiextensions.k8s.io"],
        resources: ["customresourcedefinitions"],
        verbs: ["*"]
      },
      %{apiGroups: ["bonny.test"], resources: ["widgets", "cogs"], verbs: ["*"]},
      %{apiGroups: ["apps"], resources: ["deployments", "services"], verbs: ["*"]},
      %{apiGroups: [""], resources: ["configmaps"], verbs: ["create", "read"]}
    ]

    assert manifest == expected
  end

  test "service_account/1" do
    manifest = Operator.service_account("default")

    expected = %{
      metadata: %{name: "bonny", labels: %{"k8s-app" => "bonny"}, namespace: "default"},
      apiVersion: "v1",
      kind: "ServiceAccount"
    }

    assert manifest == expected
  end

  test "crds/0" do
    manifest = Operator.crds()

    expected = [
      %{
        apiVersion: "apiextensions.k8s.io/v1beta1",
        kind: "CustomResourceDefinition",
        metadata: %{
          labels: %{"k8s-app" => "bonny"},
          name: "widgets.bonny.test"
        },
        spec: %Bonny.CRD{
          group: "bonny.test",
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
          labels: %{"k8s-app" => "bonny"},
          name: "cogs.bonny.test"
        },
        spec: %Bonny.CRD{
          group: "bonny.test",
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

    assert manifest == expected
  end

  test "cluster_role_binding/1" do
    manifest = Operator.cluster_role_binding("default")

    expected = %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRoleBinding",
      metadata: %{name: "bonny", labels: %{"k8s-app" => "bonny"}},
      roleRef: %{apiGroup: "rbac.authorization.k8s.io", kind: "ClusterRole", name: "bonny"},
      subjects: [%{kind: "ServiceAccount", name: "bonny", namespace: "default"}]
    }

    assert manifest == expected
  end
end
