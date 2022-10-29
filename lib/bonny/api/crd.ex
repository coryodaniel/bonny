defmodule Bonny.API.CRD do
  @moduledoc """
  A Custom Resource Definition.

  The `%Bonny.API.CRD{}` struct contains the fields `group`, `resource_type`,
  `scope` and `version`. New definitions can be created directly, using the
  `new!/1` function.
  """

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
  - `group`: group name to use for REST API: /apis/<group>/<version>, defaults to the group in config.exs
  - `names`: see `names_t`
  - `versions`: list of API Version modules for this Resource, defaults to the versions in config.exs
  """
  @type t :: %__MODULE__{
          group: binary(),
          names: names_t(),
          scope: :Namespaced | :Cluster,
          versions: list(module())
        }

  @enforce_keys [:names, :versions]

  defstruct [
    :names,
    :group,
    :versions,
    scope: :Namespaced
  ]

  @doc """
  Creates a new %Bonny.API.CRD{} struct from the given values. `:scope` is
  optional and defaults to `:Namespaced`.
  """
  @spec new!(keyword()) :: t()
  def new!(fields) do
    fields =
      fields
      |> Keyword.put_new(:group, Bonny.Config.group())

    struct!(__MODULE__, fields)
  end

  @doc """
  Converts the internally used structure to a map representing a kubernetes CRD manifest.
  """
  @spec to_manifest(__MODULE__.t()) :: map()
  def to_manifest(%__MODULE__{} = crd) do
    spec =
      crd
      |> Map.from_struct()
      |> update_in([Access.key(:versions, []), Access.all()], & &1.manifest())
      |> assert_single_storage!()

    %{
      apiVersion: @api_version,
      kind: @kind,
      metadata: %{
        name: "#{crd.names.plural}.#{crd.group}",
        labels: Bonny.Config.labels()
      },
      spec: spec
    }
  end

  defp assert_single_storage!(crd) do
    stored_versions_count = Enum.count(crd.versions, &(&1.storage == true))

    cond do
      stored_versions_count == 0 and length(crd.versions) == 1 ->
        Map.update!(crd, :versions, fn [version] -> [Map.put(version, :storage, true)] end)

      stored_versions_count != 1 ->
        raise ArgumentError,
              "One single version of a CRD has to be the storage version. In your CRD \"#{crd.names.kind}\", #{stored_versions_count} versions define `storage: true`. Change the `manifest/0` function and set `storage: true` in a single one of them."

      true ->
        crd
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
end
