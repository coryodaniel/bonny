defmodule Bonny.API.CRD do
  @moduledoc """
  Represents a Custom Resource Definition.
  """

  alias Bonny.API.Definition, as: APIDefinition

  @kind "CustomResourceDefinition"
  @api_version "apiextensions.k8s.io/v1"

  @typedoc """
  Defines the names section of the CRD.

  - `plural`: name to be used in the URL: /apis/<group>/<version>/<plural> - e.g. crontabs
  - `singular`: singular name to be used as an alias on the CLI and for display - e.g. crontab
  - `kind`: is normally the CamelCased singular type. Your resource manifests use this. - e.g. CronTab
  - `shortnames`: allow shorter string to match your resource on the CLI - e.g. [ct]
  """
  @type names_t :: %{
          required(:singular) => binary(),
          required(:plural) => binary(),
          required(:kind) => binary(),
          optional(:shortNames) => list(binary())
        }

  @typedoc """
  A Custom Resource Definition.

  - `scope`: either Namespaced or Cluster
  - `group`: group name to use for REST API: /apis/<group>/<version>
  - `names`: see `names_t`
  - `versions`: list of versions supported by this CustomResourceDefinition
  """
  @type t :: %__MODULE__{
          scope: :Namespaced | :Cluster,
          group: binary() | nil,
          names: names_t(),
          versions: list(Bonny.CRD.Version.t())
        }

  @enforce_keys [:group, :names, :versions]

  defstruct [
    :versions,
    :group,
    :names,
    scope: :Namespaced
  ]

  @doc """
  Creates a new %Bonny.API.CRD{} struct from the given values. `:scope` is
  optional and defaults to `:Namespaced`.
  """
  @spec new!(keyword()) :: __MODULE__.t()
  def new!(fields) do
    fields =
      fields
      |> Keyword.put_new_lazy(:versions, fn -> Keyword.get_values(fields, :version) end)
      |> Keyword.delete(:version)

    struct!(__MODULE__, fields)
  end

  @doc """
  Changes the internally used structure into a map representing a kubernetes CRD manifest
  """
  @spec to_manifest(__MODULE__.t()) :: map()
  def to_manifest(%__MODULE__{} = crd) do
    check_single_storage!(crd)

    %{
      apiVersion: @api_version,
      kind: @kind,
      metadata: %{
        name: "#{crd.names.plural}.#{crd.group}",
        labels: Bonny.Operator.labels()
      },
      spec: Map.from_struct(crd)
    }
  end

  def api_definition(crd) do
    APIDefinition.new!(
      group: crd.group,
      resource_type: crd.names.plural,
      scope: crd.scope,
      version: stored_version(crd)
    )
  end

  defp stored_version(crd) do
    crd.versions
    |> Enum.find(&(&1.storage == true))
    |> Map.get(:name)
  end

  defp check_single_storage!(crd) do
    no_stored_versions = Enum.count(crd.versions, &(&1.storage == true))

    if no_stored_versions != 1 do
      raise ArgumentError,
            "Only one single version of a CRD can have the attribute \"storage\" set to true. In your CRD #{no_stored_versions} versions define `storage: true`."
    end
  end

  @doc """
  Build a map of names form the given kind.

  ### Examples

      iex> Bonny.API.CRD.kind_to_names("SomeKind")
      %{singular: "somekind", plural: "somekinds", kind: "SomeKind", shortNames: []}

    The `:inflex` library is used to generate the plural form.

      iex> Bonny.API.CRD.kind_to_names("Hero")
      %{singular: "hero", plural: "heroes", kind: "Hero", shortNames: []}

    Accepts an optional list of abbreviations as second argument.

      iex> Bonny.API.CRD.kind_to_names("SomeKind", ["sk", "some"])
      %{singular: "somekind", plural: "somekinds", kind: "SomeKind", shortNames: ["sk", "some"]}

  """
  @spec kind_to_names(binary(), list(binary())) :: names_t()
  def kind_to_names(kind, short_names \\ []) do
    singular = String.downcase(kind)
    plural = Inflex.pluralize(singular)

    %{
      kind: kind,
      singular: singular,
      plural: plural,
      shortNames: short_names
    }
  end

  @doc """
  Calls updates all versions of the given CRD by calling `fun`.

  ### Examples

      iex> crd = Bonny.API.CRD.new!(versions: [Bonny.CRD.Version.new!(name: "v1")], group: "", names: [])
      ...> Bonny.API.CRD.update_versions(crd, & struct!(&1, name: "v1beta1"))
      %Bonny.API.CRD{
              group: "",
              names: [],
              scope: :Namespaced,
              versions: [%Bonny.CRD.Version{
                name: "v1beta1",
                served: true,
                storage: true,
                deprecated: false,
                deprecationWarning: nil,
                schema: %{openAPIV3Schema: %{type: :object, "x-kubernetes-preserve-unknown-fields": true}},
                additionalPrinterColumns: [],
                subresources: %{}
              }]
            }
  """
  @spec update_versions(t(), (Bonny.CRD.Version.t() -> Bonny.CRD.Version.t())) :: t()
  def update_versions(crd, fun) do
    update_in(crd, [Access.key(:versions), Access.all()], fun)
  end

  @doc """
  Calls updates all versions of the given CRD for which `filter`
  resolves truthy, by calling `fun`.

  ### Examples

      iex> crd = Bonny.API.CRD.new!(versions: [Bonny.CRD.Version.new!(name: "v1beta1"), Bonny.CRD.Version.new!(name: "v1")], group: "", names: [])
      ...> Bonny.API.CRD.update_versions(crd, & &1.name == "v1beta1", & struct!(&1, storage: false))
      %Bonny.API.CRD{
              group: "",
              names: [],
              scope: :Namespaced,
              versions: [
                %Bonny.CRD.Version{
                  name: "v1beta1",
                  served: true,
                  storage: false,
                  deprecated: false,
                  deprecationWarning: nil,
                  schema: %{openAPIV3Schema: %{type: :object, "x-kubernetes-preserve-unknown-fields": true}},
                  additionalPrinterColumns: [],
                  subresources: %{}
                },
                %Bonny.CRD.Version{
                  name: "v1",
                  served: true,
                  storage: true,
                  deprecated: false,
                  deprecationWarning: nil,
                  schema: %{openAPIV3Schema: %{type: :object, "x-kubernetes-preserve-unknown-fields": true}},
                  additionalPrinterColumns: [],
                  subresources: %{}
                }
              ]
            }
  """
  @spec update_versions(
          t(),
          (Bonny.CRD.Version.t() -> boolean()),
          (Bonny.CRD.Version.t() -> Bonny.CRD.Version.t())
        ) :: t()
  def update_versions(crd, filter, fun) do
    update_in(crd, [Access.key(:versions), Access.filter(filter)], fun)
  end
end
