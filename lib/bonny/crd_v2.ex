defmodule Bonny.CRDV2 do
  @moduledoc """
  Represents a Custom Resource Definition.
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

  @spec new!(keyword()) :: __MODULE__.t()
  def new!(fields) do
    struct!(__MODULE__, fields)
  end

  @spec to_manifest(__MODULE__.t()) :: map()
  def to_manifest(%__MODULE__{} = crd) do
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
