defmodule Bonny.CRD do
  @moduledoc """
  Represents the `spec` portion of a Kubernetes [CustomResourceDefinition](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/) manifest.

  > The CustomResourceDefinition API resource allows you to define custom resources. Defining a CRD object creates a new custom resource with a name and schema that you specify. The Kubernetes API serves and handles the storage of your custom resource.
  """
  alias Bonny.CRD

  @api_version "apiextensions.k8s.io/v1beta1"
  @kind "CustomResourceDefinition"

  @type names_t :: %{
          kind: String.t(),
          singular: String.t(),
          plural: String.t(),
          short_names: nil | list(String.t()),
          version: String.t()
        }

  @typedoc "CRD Spec"
  @type t :: %__MODULE__{
          scope: :namespaced | :cluster,
          group: String.t(),
          names: names_t,
          version: String.t()
        }

  @enforce_keys [:scope, :group, :names]
  defstruct scope: :namespaced,
            group: nil,
            names: nil,
            version: nil

  @doc """
  URL Path to list a CRD's resources

  *Namespaced CRD URL Path*
  /apis/bonny.example.om/v1/namespaces/default/widgets

  *Cluster Resource URL Path & `--all-namespaces` path*
  /apis/bonny.example.io/v1/widgets
  """
  @spec list_path(Bonny.CRD.t()) :: binary
  def list_path(crd = %CRD{}), do: base_path(crd)

  @spec watch_path(Bonny.CRD.t(), String.t() | integer) :: binary
  def watch_path(crd = %CRD{}, resource_version) do
    "#{base_path(crd)}?resourceVersion=#{resource_version}&watch=true"
  end

  @doc """
  URL path to read the specified CustomResourceDefinition

  *Namespaced CRD Resource URL Path*
  /apis/bonny.example.io/v1/namespaces/default/widgets/test-widget

  *Cluster CRD Resource URL Path & `--all-namespaces` path*
  /apis/bonny.example.io/v1/widgets/test-widget
  """
  @spec read_path(Bonny.CRD.t(), String.t()) :: binary
  def read_path(crd = %CRD{}, name) do
    "#{base_path(crd)}/#{name}"
  end

  @doc """
  Generates the map equivalent of the Kubernetes CRD YAML manifest

  ```yaml
  ---
  apiVersion: apiextensions.k8s.io/v1beta1
  kind: CustomResourceDefinition
  metadata:
    creationTimestamp: null
    name: widgets.bonny.example.io
  spec:
    group: bonny.example.io
    names:
      kind: Widget
      plural: widgets
    scope: Namespaced
    version: v1
  ```
  """
  @spec to_manifest(Bonny.CRD.t()) :: map
  def to_manifest(crd = %CRD{scope: scope}) do
    cased_scope = String.capitalize("#{scope}")

    %{
      apiVersion: @api_version,
      kind: @kind,
      metadata: %{
        name: "#{crd.names.plural}.#{crd.group}",
        labels: Bonny.Operator.labels()
      },
      spec: %{crd | scope: cased_scope}
    }
  end

  defp base_path(%CRD{
         scope: :namespaced,
         version: version,
         group: group,
         names: %{plural: plural}
       }) do
    "/apis/#{group}/#{version}/namespaces/#{Bonny.namespace()}/#{plural}"
  end

  defp base_path(%CRD{scope: :cluster, version: version, group: group, names: %{plural: plural}}) do
    "/apis/#{group}/#{version}/#{plural}"
  end
end
