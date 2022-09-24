defmodule Bonny.API.Definition do
  @typedoc """
  A Resource API Definition.

  - `scope`: either Namespaced or Cluster
  - `group`: group name to use for REST API: /apis/<group>/<version>
  - `names`: see `names_t`
  """
  @type t :: %__MODULE__{
          group: binary() | nil,
          resource_type: binary(),
          scope: :Namespaced | :Cluster,
          version: binary()
        }

  defstruct [:group, :resource_type, :version, scope: :Namespaced]

  @doc """
  Creates a new %Bonny.API.CRD{} struct from the given values. `:scope` is
  optional and defaults to `:Namespaced`.
  """
  @spec new!(keyword()) :: __MODULE__.t()
  def new!(fields) do
    struct!(__MODULE__, fields)
  end

  @doc """
  Gets apiVersion of the actual resources.

  ## Examples
    Returns apiVersion for an operator

      iex> Bonny.API.CRD.resource_api_version(%Bonny.API.CRD{group: "hello.example.com", versions: [Bonny.CRD.Version.new!(name: "v1")], scope: :namespaced, names: %{}})
      "hello.example.com/v1"

    Returns apiVersion for `apps` resources

      iex> Bonny.API.CRD.resource_api_version(%Bonny.API.CRD{group: "apps", versions: [Bonny.CRD.Version.new!(name: "v1")], scope: :namespaced, names: %{}})
      "apps/v1"

    Returns apiVersion for `core` resources

      iex> Bonny.API.CRD.resource_api_version(%Bonny.API.CRD{group: "", versions: [Bonny.CRD.Version.new!(name: "v1")], scope: :namespaced, names: %{}})
      "v1"

      iex> Bonny.API.CRD.resource_api_version(%Bonny.API.CRD{group: nil, versions: [Bonny.CRD.Version.new!(name: "v1")], scope: :namespaced, names: %{}})
      "v1"

    Returs apiVresion of stored version if there are multiple

      iex> Bonny.API.CRD.resource_api_version(%Bonny.API.CRD{group: "", versions: [Bonny.CRD.Version.new!(name: "v1beta1", storage: false), Bonny.CRD.Version.new!(name: "v1")], scope: :namespaced, names: %{}})
      "v1"
  """
  @spec resource_api_version(t()) :: String.t()
  def resource_api_version(definition),
    do: api_group_prefix(definition) <> definition.version

  defp api_group_prefix(%__MODULE__{group: ""}), do: ""
  defp api_group_prefix(%__MODULE__{group: nil}), do: ""
  defp api_group_prefix(%__MODULE__{group: g}), do: "#{g}/"
end
