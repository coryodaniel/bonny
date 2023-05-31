defmodule Bonny.Mix.Operator do
  @moduledoc """
  Encapsulates Kubernetes resource manifests for an operator
  """

  @doc "ClusterRole manifest"
  @spec cluster_role(list(atom)) :: map()
  def cluster_role(operators) do
    %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRole",
      metadata: %{
        name: Bonny.Config.service_account(),
        labels: labels()
      },
      rules: rbac_rules(operators)
    }
  end

  def rbac_rules(operators) do
    rules =
      for rule <- base_rules() ++ legacy_rules() ++ operator_rules(operators),
          api_group <- rule.apiGroups,
          resource <- rule.resources,
          verb <- rule.verbs,
          reduce: %{} do
        acc ->
          if verb == "*" or Map.get(acc, {api_group, resource}) == ["*"] do
            Map.put(acc, {api_group, resource}, ["*"])
          else
            Map.update(acc, {api_group, resource}, [verb], &[verb | &1])
          end
      end

    rules
    |> Enum.map(fn {{api_group, resource}, verbs} ->
      %{apiGroups: [api_group], resources: [resource], verbs: verbs |> Enum.uniq() |> Enum.sort()}
    end)
    |> Enum.sort_by(&{&1.apiGroups, &1.resources})
  end

  defp base_rules() do
    [
      %{
        apiGroups: ["apiextensions.k8s.io"],
        resources: ["customresourcedefinitions"],
        verbs: ["*"]
      },
      %{
        apiGroups: ["events.k8s.io"],
        resources: ["events"],
        verbs: ["*"]
      },
      %{
        apiGroups: ["coordination.k8s.io"],
        resources: ["leases"],
        verbs: ["*"]
      }
    ]
  end

  @spec legacy_rules() :: list(map())
  defp legacy_rules() do
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

    resource_rules ++ controller_rules
  end

  defp operator_rules(operators) do
    for operator <- operators,
        %{query: query, controller: controller} <- operator.controllers("default", []) do
      crd_rules(query, operator.crds()) ++ controller_rules(controller)
    end
    |> List.flatten()
  end

  defp controller_rules({controller, _opts}), do: controller.rbac_rules()
  defp controller_rules(nil), do: []
  defp controller_rules(controller), do: controller.rbac_rules()

  defp crd_rules(query, crds) do
    case find_matching_crd(query, crds) do
      nil ->
        []

      crd ->
        api_group = String.replace(query.api_version, ~r/^([^\/]*)\/?.*$/, "\\1")

        [
          %{
            apiGroups: [api_group],
            resources: [crd.names.plural],
            verbs: ["*"]
          },
          %{
            apiGroups: [api_group],
            resources: [crd.names.plural <> "/status"],
            verbs: ["*"]
          }
        ]
    end
  end

  defp find_matching_crd(query, crds) do
    Enum.find(crds, fn %Bonny.API.CRD{names: names, versions: versions, group: group} ->
      query.name in [names.plural, names.singular, names.kind] &&
        Enum.any?(versions, &(group <> "/" <> &1.manifest().name == query.api_version))
    end)
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
  @spec crds(list(atom())) :: list(map())
  def crds(operators) do
    legacy_crds =
      Enum.flat_map(
        Bonny.Config.controllers(),
        &[Bonny.CRD.to_manifest(&1.crd(), Bonny.Config.api_version())]
      )

    operator_crds =
      Enum.flat_map(operators, fn operator ->
        Enum.map(operator.crds(), &Bonny.API.CRD.to_manifest/1)
      end)

    legacy_crds ++ operator_crds
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
      env_field_ref("BONNY_POD_SERVICE_ACCOUNT", "spec.serviceAccountName"),
      env_field_ref("BONNY_OPERATOR_NAME", Bonny.Config.name())
    ]
  end

  @spec find_operators() :: list(atom())
  def find_operators() do
    {:ok, modules} =
      Mix.Project.config()
      |> Keyword.fetch!(:app)
      |> :application.get_key(:modules)

    Enum.filter(modules, &(Bonny.Operator in get_module_behaviours(&1)))
  end

  defp get_module_behaviours(module) do
    module.module_info(:attributes)
    |> Keyword.get_values(:behaviour)
    |> List.flatten()
  end
end
