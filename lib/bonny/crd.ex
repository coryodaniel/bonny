defmodule Bonny.CRD do
  @moduledoc """
  Represents the `spec` portion of a Kubernetes [CustomResourceDefinition](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/) manifest.

  > The CustomResourceDefinition API resource allows you to define custom resources. Defining a CRD object creates a new custom resource with a name and schema that you specify. The Kubernetes API serves and handles the storage of your custom resource.
  """
  alias Bonny.CRD

  @api_version "apiextensions.k8s.io/v1beta1"
  @kind "CustomResourceDefinition"

  @typep names_t :: %{
           kind: String.t(),
           singular: String.t(),
           plural: String.t(),
           shortNames: nil | list(String.t()),
           version: String.t()
         }

  @typep columns_t :: %{
           name: String.t(),
           type: String.t(),
           description: String.t(),
           JSONPath: String.t()
         }

  @typedoc "CRD Spec"
  @type t :: %__MODULE__{
          scope: :namespaced | :cluster,
          group: String.t(),
          names: names_t,
          version: String.t(),
          additionalPrinterColumns: list(columns_t)
        }

  @enforce_keys [:scope, :group, :names]
  @derive Jason.Encoder
  defstruct scope: :namespaced,
            group: nil,
            names: nil,
            version: nil,
            additionalPrinterColumns: nil

  @doc """
  CRD Kind or plural name

  ## Examples

      iex> Bonny.CRD.kind(%Bonny.CRD{names: %{plural: "greetings"}, scope: :namespaced, group: "test", version: "v1"})
      "greetings"

  """
  @spec kind(Bonny.CRD.t()) :: binary
  def kind(%Bonny.CRD{names: %{plural: plural}}), do: plural

  @doc """
  Gets group version from CRD spec

  ## Examples

      iex> Bonny.CRD.api_version(%Bonny.CRD{group: "hello.example.com", version: "v1", scope: :namespaced, names: %{}})
      "hello.example.com/v1"

  """
  @spec api_version(Bonny.CRD.t()) :: binary
  def api_version(%Bonny.CRD{group: g, version: v}), do: "#{g}/#{v}"

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

  @doc false
  @spec telemetry_metadata(Bonny.CRD.t(), map | nil) :: map
  def telemetry_metadata(spec = %Bonny.CRD{}, extra \\ %{}) do
    base = %{
      api_version: Bonny.CRD.api_version(spec),
      kind: Bonny.CRD.kind(spec)
    }

    Map.merge(base, extra)
  end
end
