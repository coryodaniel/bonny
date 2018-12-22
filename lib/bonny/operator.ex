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
        labels: labels()
      },
      rules: rules
    }
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
        labels: labels()
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
        labels: labels()
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

  @doc false
  @spec deployment(binary(), binary()) :: map
  def deployment(image, namespace) do
    deployment_labels = %{"k8s-app" => Bonny.name()}

    %{
      apiVersion: "apps/v1beta2",
      kind: "Deployment",
      metadata: %{
        labels: labels(),
        name: Bonny.service_account(),
        namespace: namespace
      },
      spec: %{
        replicas: 1,
        selector: %{matchLabels: deployment_labels},
        template: %{
          metadata: %{labels: deployment_labels},
          spec: %{
            containers: [
              %{
                image: image,
                name: Bonny.name(),
                resources: default_resources(),
                securityContext: %{
                  allowPrivilegeEscalation: false,
                  readOnlyRootFilesystem: true
                },
                env: env_vars()
              }
            ],
            securityContext: %{runAsNonRoot: true, runAsUser: 65_534},
            serviceAccountName: Bonny.service_account()
          }
        }
      }
    }
  end

  @doc false
  def labels(), do: labels(%{})
  def labels(addl) do
    default_labels = %{
      bonny: "true"
    }

    Map.merge(default_labels, addl)
  end

  @doc false
  defp default_resources do
    %{
      limits: %{cpu: "200m", memory: "200Mi"},
      requests: %{cpu: "200m", memory: "200Mi"}
    }
  end

  @doc false
  defp env_field_ref(name, path) do
    %{
      name: name,
      valueFrom: %{
        fieldRef: %{
          fieldPath: path
        }
      }
    }
  end

  @doc false
  defp env_vars() do
    [
      %{name: "MIX_ENV", value: "prod"},
      env_field_ref("BONNY_POD_NAME", "metadata.name"),
      env_field_ref("BONNY_POD_NAMESPACE", "metadata.namespace"),
      env_field_ref("BONNY_POD_IP", "status.podIP"),
      env_field_ref("BONNY_POD_SERVICE_ACCOUNT", "spec.serviceAccountName"),
    ]
  end
end
