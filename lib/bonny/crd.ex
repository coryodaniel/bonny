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
          additional_printer_columns: list(columns_t)
        }

  @enforce_keys [:scope, :group, :names]
  @derive Jason.Encoder
  defstruct additional_printer_columns: nil,
            group: nil,
            names: nil,
            scope: :namespaced,
            version: nil

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
  def to_manifest(%CRD{} = crd) do
    %{
      apiVersion: @api_version,
      kind: @kind,
      metadata: %{
        name: "#{crd.names.plural}.#{crd.group}",
        labels: Bonny.Operator.labels()
      },
      spec: format_spec(crd)
    }
  end

  @doc """
  Default CLI printer columns.

  These are added to the CRDs columns _when_ columns are set.

  The kubernetes API returns these by default when they _are not_ set.
  """
  @spec default_columns() :: list(map())
  def default_columns() do
    [
      %{
        name: "Age",
        type: "date",
        description:
          "CreationTimestamp is a timestamp representing the server time when this object was created. It is not guaranteed to be set in happens-before order across separate operations. Clients may not set this value. It is represented in RFC3339 form and is in UTC.

      Populated by the system. Read-only. Null for lists. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata",
        JSONPath: ".metadata.creationTimestamp"
      }
    ]
  end

  @spec format_spec(Bonny.CRD.t()) :: map
  defp format_spec(%CRD{scope: scope} = crd) do
    cased_scope = String.capitalize("#{scope}")

    crd
    |> Map.from_struct()
    |> Map.put(:scope, cased_scope)
    |> rename_keys(keys_to_rename())
  end

  @spec rename_keys(map, map) :: map
  defp rename_keys(map, keymap) do
    Enum.reduce(keymap, map, fn {oldkey, newkey}, agg ->
      value = Map.get(agg, oldkey)

      agg
      |> Map.drop([oldkey])
      |> Map.put(newkey, value)
    end)
  end

  @spec keys_to_rename() :: map
  defp keys_to_rename() do
    %{
      additional_printer_columns: :additionalPrinterColumns
    }
  end
end
