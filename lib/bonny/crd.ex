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
          shortNames: nil | list(String.t()),
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
  @derive Jason.Encoder
  defstruct scope: :namespaced,
            group: nil,
            names: nil,
            version: nil

  @doc """
  Plural name of CRD

  ## Examples

      iex> Bonny.CRD.plural(%Bonny.CRD{names: %{plural: "greetings"}, scope: :namespaced, group: "test", version: "v1"})
      "greetings"

  """
  @spec plural(Bonny.CRD.t()) :: binary
  def plural(%Bonny.CRD{names: %{plural: plural}}), do: plural

  @doc """
  Gets group version from CRD spec

  ## Examples

      iex> Bonny.CRD.group_version(%Bonny.CRD{group: "hello.example.com", version: "v1", scope: :namespaced, names: %{}})
      "hello.example.com/v1"

  """
  @spec group_version(Bonny.CRD.t()) :: binary
  def group_version(%Bonny.CRD{group: g, version: v}), do: "#{g}/#{v}"

  @doc """
  Generates the map equivalent of the Kubernetes CRD YAML manifest

  ```yaml
  ---
  apiVersion: apiextensions.k8s.io/v1beta1
  kind: CustomResourceDefinition
  metadata:
    creationTimestamp: null
    name: widgets.example.com
  spec:
    group: example.com
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
end
