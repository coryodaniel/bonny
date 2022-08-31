defmodule Bonny.CRD do
  @moduledoc """
  Represents the `spec` portion of a Kubernetes [CustomResourceDefinition](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/) manifest.

  > The CustomResourceDefinition API resource allows you to define custom resources. Defining a CRD object creates a new custom resource with a name and schema that you specify. The Kubernetes API serves and handles the storage of your custom resource.
  """
  alias Bonny.CRD

  @kind "CustomResourceDefinition"

  @typep names_t :: %{
           kind: String.t(),
           singular: String.t(),
           plural: String.t(),
           shortNames: nil | list(String.t())
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
          group: String.t() | nil,
          names: names_t,
          version: String.t(),
          additional_printer_columns: list(columns_t)
        }

  @enforce_keys [:scope, :group, :names]
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
    Returns apiVersion for an operator

      iex> Bonny.CRD.api_version(%Bonny.CRD{group: "hello.example.com", version: "v1", scope: :namespaced, names: %{}})
      "hello.example.com/v1"

    Returns apiVersion for `apps` resources

      iex> Bonny.CRD.api_version(%Bonny.CRD{group: "apps", version: "v1", scope: :namespaced, names: %{}})
      "apps/v1"

    Returns apiVersion for `core` resources

      iex> Bonny.CRD.api_version(%Bonny.CRD{group: "", version: "v1", scope: :namespaced, names: %{}})
      "v1"

      iex> Bonny.CRD.api_version(%Bonny.CRD{group: nil, version: "v1", scope: :namespaced, names: %{}})
      "v1"

  """
  @spec api_version(Bonny.CRD.t()) :: String.t()
  def api_version(%Bonny.CRD{group: nil, version: v}), do: v
  def api_version(%Bonny.CRD{group: "", version: v}), do: v
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
  @spec to_manifest(Bonny.CRD.t(), String.t()) :: map
  def to_manifest(%CRD{} = crd, api_version \\ "apiextensions.k8s.io/v1beta1") do
    spec =
      case api_version do
        "apiextensions.k8s.io/v1" -> format_spec_v1(crd)
        _ -> format_spec_v1beta1(crd)
      end

    %{
      apiVersion: api_version,
      kind: @kind,
      metadata: %{
        name: "#{crd.names.plural}.#{crd.group}",
        labels: Bonny.Operator.labels()
      },
      spec: spec
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

  @spec format_spec_v1beta1(Bonny.CRD.t()) :: map
  defp format_spec_v1beta1(%CRD{scope: scope} = crd) do
    cased_scope = String.capitalize("#{scope}")

    crd
    |> Map.from_struct()
    |> Map.put(:scope, cased_scope)
    |> rename_keys(keys_to_rename())
  end

  @spec format_spec_v1(Bonny.CRD.t()) :: map
  defp format_spec_v1(
         %CRD{
           version: version,
           additional_printer_columns: additional_printer_columns,
           scope: scope
         } = crd
       ) do
    cased_scope = String.capitalize("#{scope}")

    additional_printer_columns_v1 =
      additional_printer_columns
      |> Enum.map(fn elem -> rename_keys(elem, %{JSONPath: :jsonPath}) end)

    crd
    |> Map.from_struct()
    |> Map.drop([:version, :additional_printer_columns])
    |> Map.put(:scope, cased_scope)
    |> Map.put(:versions, [
      %{
        name: version,
        served: true,
        storage: true,
        schema: %{
          openAPIV3Schema: %{
            type: "object",
            "x-kubernetes-preserve-unknown-fields": true
          }
        },
        additionalPrinterColumns: additional_printer_columns_v1
      }
    ])
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
