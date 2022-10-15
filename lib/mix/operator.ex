defmodule Bonny.Mix.Operator do
  @moduledoc """
  Encapsulates Kubernetes resource manifests for an operator
  """

  @doc "ClusterRole manifest"
  @spec cluster_role() :: map()
  def cluster_role() do
    %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRole",
      metadata: %{
        name: Bonny.Config.service_account(),
        labels: labels()
      },
      rules: rules()
    }
  end

  @doc "ClusterRole rules"
  @spec rules() :: list(map())
  def rules() do
    base_rules = [
      %{
        apiGroups: ["apiextensions.k8s.io"],
        resources: ["customresourcedefinitions"],
        verbs: ["*"]
      },
      %{
        apiGroups: ["events.k8s.io/v1"],
        resources: ["events"],
        verbs: ["*"]
      }
    ]

    resource_rules =
      Enum.map(Bonny.Config.controllers(), fn controller ->
        resource_endpoint = controller.resource_endpoint()

        %{
          apiGroups: [resource_endpoint.group || ""],
          resources: [resource_endpoint.resource_type],
          verbs: ["*"]
        }
      end)

    controller_rules = Enum.flat_map(Bonny.Config.controllers(), & &1.rules())

    Enum.uniq(base_rules ++ resource_rules ++ controller_rules)
  end

  @doc "ServiceAccount manifest"
  @spec service_account(binary()) :: map()
  def service_account(namespace) do
    %{
      apiVersion: "v1",
      kind: "ServiceAccount",
      metadata: %{
        name: Bonny.Config.service_account(),
        namespace: namespace,
        labels: labels()
      }
    }
  end

  @doc "CRD manifests"
  @spec crds() :: list(map())
  def crds() do
    Enum.flat_map(Bonny.Config.controllers(), fn controller ->
      attributes = controller.module_info(:attributes)

      cond do
        Enum.member?(attributes, {:behaviour, [Bonny.Controller]}) ->
          [Bonny.CRD.to_manifest(controller.crd(), Bonny.Config.api_version())]

        Enum.member?(attributes, {:behaviour, [Bonny.ControllerV2]}) and
            function_exported?(controller, :crd_manifest, 0) ->
          [controller.crd_manifest()]

        true ->
          []
      end
    end)
  end

  @doc "ClusterRoleBinding manifest"
  @spec cluster_role_binding(binary()) :: map()
  def cluster_role_binding(namespace) do
    %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRoleBinding",
      metadata: %{
        name: Bonny.Config.service_account(),
        labels: labels()
      },
      roleRef: %{
        apiGroup: "rbac.authorization.k8s.io",
        kind: "ClusterRole",
        name: Bonny.Config.service_account()
      },
      subjects: [
        %{
          kind: "ServiceAccount",
          name: Bonny.Config.service_account(),
          namespace: namespace
        }
      ]
    }
  end

  @doc "Deployment manifest"
  @spec deployment(binary(), binary()) :: map
  def deployment(image, namespace) do
    %{
      apiVersion: "apps/v1",
      kind: "Deployment",
      metadata: %{
        labels: labels(),
        name: Bonny.Config.name(),
        namespace: namespace
      },
      spec: %{
        replicas: 1,
        selector: %{matchLabels: labels()},
        template: %{
          metadata: %{labels: labels()},
          spec: %{
            serviceAccountName: Bonny.Config.service_account(),
            containers: [
              %{
                image: image,
                name: Bonny.Config.name(),
                resources: resources(),
                securityContext: %{
                  allowPrivilegeEscalation: false,
                  readOnlyRootFilesystem: true,
                  runAsNonRoot: true,
                  runAsUser: 65_534
                },
                env: env_vars()
              }
            ]
          }
        }
      }
    }
  end

  @doc false
  @spec labels() :: map()
  def labels() do
    operator_labels = Bonny.Config.labels()
    default_labels = %{"k8s-app" => Bonny.Config.name()}

    Map.merge(default_labels, operator_labels)
  end

  @doc false
  @spec resources() :: map()
  defp resources() do
    Application.get_env(:bonny, :resources, %{
      limits: %{cpu: "200m", memory: "200Mi"},
      requests: %{cpu: "200m", memory: "200Mi"}
    })
  end

  @doc false
  @spec env_field_ref(binary, binary) :: map()
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
  @spec env_vars() :: list(map())
  defp env_vars() do
    [
      %{name: "MIX_ENV", value: "prod"},
      env_field_ref("BONNY_POD_NAME", "metadata.name"),
      env_field_ref("BONNY_POD_NAMESPACE", "metadata.namespace"),
      env_field_ref("BONNY_POD_IP", "status.podIP"),
      env_field_ref("BONNY_POD_SERVICE_ACCOUNT", "spec.serviceAccountName")
    ]
  end
end
