defmodule Bonny.Operator do
  @moduledoc """
  Encapsulates Kubernetes resource manifests for an operator
  """

  @doc false
  @spec cluster_role() :: map()
  def cluster_role() do
    rules =
      Enum.reduce(Bonny.controllers(), [], fn controller, acc ->
        acc ++ controller.rules()
      end)

    %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRole",
      metadata: %{
        name: Bonny.service_account(),
        labels: Bonny.Operator.labels()
      },
      rules: rules
    }
  end

  def labels(addl \\ %{}) do
    default_labels = %{
      bonny: "#{Application.spec(:bonny, :vsn)}"
    }

    Map.merge(default_labels, addl)
  end

  @doc false
  @spec service_account(binary()) :: map()
  def service_account(namespace) do
    %{
      apiVersion: "v1",
      kind: "ServiceAccount",
      metadata: %{
        name: Bonny.service_account(),
        namespace: namespace,
        labels: Bonny.Operator.labels()
      }
    }
  end

  @doc false
  @spec crds() :: list(map())
  def crds() do
    Enum.map(Bonny.controllers(), fn controller ->
      Bonny.CRD.to_manifest(controller.crd_spec())
    end)
  end

  @doc false
  @spec cluster_role_binding(binary()) :: map()
  def cluster_role_binding(namespace) do
    %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRoleBinding",
      metadata: %{
        name: Bonny.service_account(),
        labels: Bonny.Operator.labels()
      },
      roleRef: %{
        apiGroup: "rbac.authorization.k8s.io",
        kind: "ClusterRole",
        name: Bonny.service_account()
      },
      subjects: [
        %{
          kind: "ServiceAccount",
          name: Bonny.service_account(),
          namespace: namespace
        }
      ]
    }
  end
end
