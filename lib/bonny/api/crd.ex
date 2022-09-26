defmodule Bonny.API.CRD do
  @moduledoc """
  A Custom Resource Definition.

  The %Bonny.API.CRD{} struct contains the fields `group`, `resource_type`,
  `scope` and `version`. New definitions can be created directly, using the
  `new!/1` function or from inside a controller using the
  `build_for_controller!/1` macro.
  """

  alias Bonny.API.ResourceEndpoint, as: APIDefinition

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
          group: binary() | nil,
          names: names_t(),
          scope: :Namespaced | :Cluster,
          versions: list(module())
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
  @spec new!(keyword()) :: t()
  def new!(fields), do: struct!(__MODULE__, fields)

  @doc """
  This macro can be used from inside a controller to build a new
  %Bonny.API.CRD{} struct. It's going to derive the CRD names from the
  controller's module name and takes the group from config.
  """
  defmacro build_for_controller!(fields) do
    kind = __CALLER__.module |> Module.split() |> Enum.reverse() |> hd()

    quote do
      unquote(fields)
      |> Keyword.put_new_lazy(:names, fn -> Bonny.API.CRD.kind_to_names(unquote(kind)) end)
      |> Keyword.put_new_lazy(:group, fn -> Bonny.Config.group() end)
      |> Bonny.API.CRD.new!()
    end
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
        labels: Bonny.Operator.labels()
      },
      spec: spec
    }
  end

  @doc """
  The resource endpoint for this CRD.
  """
  @spec resource_endpoint(t()) :: Bonny.API.ResourceEndpoint.t()
  def resource_endpoint(crd) do
    manifest = to_manifest(crd)

    APIDefinition.new!(
      group: manifest.spec.group,
      resource_type: manifest.spec.names.plural,
      scope: manifest.spec.scope,
      version: stored_version(manifest)
    )
  end

  defp stored_version(manifest) do
    manifest.spec.versions
    |> Enum.find(&(&1.storage == true))
    |> Map.get(:name)
  end

  defp assert_single_storage!(crd) do
    stored_versions_count = Enum.count(crd.versions, &(&1.storage == true))

    cond do
      stored_versions_count == 0 and length(crd.versions) == 1 ->
        Map.update!(crd, :versions, fn [version] -> [Map.put(version, :storage, true)] end)

      stored_versions_count != 1 ->
        raise ArgumentError,
              "One single version of a CRD has to be the hub. In your CRD \"#{crd.names.kind}\", #{stored_versions_count} versions define `hub: true`."

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
