defmodule Bonny.CRD.Version do
  @moduledoc """
  A CRD can describe multiple versions of a resource. This module helps dealing with those versions.
  """

  @typedoc """
  Defines an [additional printer column](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#additional-printer-columns).
  """
  @type printer_column_t :: %{
          required(:name) => String.t(),
          required(:type) => String.t() | atom(),
          optional(:description) => String.t(),
          required(:jsonPath) => String.t()
        }

  @typedoc """
  Defines an [OpenAPI V3 Schema](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#specifying-a-structural-schema).

  The typespec might be incomplete. Please open a PR with your additions and links to the relevant documentation, thanks.
  """
  @type schema_t :: %{
          required(:schema) => %{
            required(:openAPIV3Schema) => %{
              required(:type) =>
                :array | :boolean | :date | :integer | :number | :object | :string,
              required(:description) => binary(),
              optional(:format) =>
                :int32 | :int64 | :float | :double | :byte | :date | :"date-time" | :password,
              optional(:properties) => %{
                required(atom() | binary()) => schema_t()
              },
              optional(:additionalProperties) => schema_t() | boolean(),
              optional(:items) => schema_t(),
              optional(:"x-kubernetes-preserve-unknown-fields") => boolean(),
              optional(:"x-kubernetes-int-or-string") => boolean(),
              optional(:"x-kubernetes-embedded-resource") => boolean(),
              optional(:"x-kubernetes-validations") =>
                list(%{
                  required(:rule) => binary(),
                  optional(:message) => binary()
                }),
              optional(:pattern) => binary(),
              optional(:anyOf) => schema_t(),
              optional(:allOf) => schema_t(),
              optional(:oneOf) => schema_t(),
              optional(:not) => schema_t(),
              optional(:nullable) => boolean(),
              optional(:default) => any()
            }
          }
        }
  @typedoc """
  Defines a version of a custom resource. Refer to the [CRD versioning documentation](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/)
  """

  @type subresources_t :: %{
          optional(:status) => %{},
          optional(:scale) => %{
            required(:specReplicasPath) => binary(),
            required(:statusReplicasPath) => binary(),
            required(:labelSelectorPath) => binary()
          }
        }

  @type t :: %__MODULE__{
          name: binary(),
          served: boolean(),
          storage: boolean(),
          deprecated: boolean(),
          deprecationWarning: nil | binary(),
          schema: schema_t(),
          additionalPrinterColumns: list(printer_column_t()),
          subresources: subresources_t()
        }

  defstruct [
    :name,
    served: true,
    storage: true,
    deprecated: false,
    deprecationWarning: nil,
    schema: %{openAPIV3Schema: %{type: :object, "x-kubernetes-preserve-unknown-fields": true}},
    additionalPrinterColumns: [],
    subresources: %{}
  ]

  @spec new!(keyword()) :: __MODULE__.t()
  def new!(fields) do
    struct!(__MODULE__, fields)
  end

  @doc """
  Adds the status subresource if it hasn't been added before
  and adds a field .status.observedGeneration of type integer
  to the OpenAPIV3Schema.

  ### Example

      iex> Bonny.CRD.Version.add_observed_generation_status(%{})
      %{
        subresources: %{status: %{}},
        schema: %{
          openAPIV3Schema: %{
            type: :object,
            properties: %{
              status: %{
                type: :object,
                properties: %{
                  observedGeneration: %{type: :integer}
                }
              }
            }
          }
        }
      }
  """
  @spec add_observed_generation_status(t()) :: t()
  def add_observed_generation_status(version) do
    version
    |> put_in([Access.key(:subresources, %{}), :status], %{})
    |> put_in(
      [
        Access.key(:schema, %{}),
        Access.key(:openAPIV3Schema, %{type: :object}),
        Access.key(:properties, %{}),
        Access.key(:status, %{type: :object, properties: %{}}),
        Access.key(:properties, %{}),
        :observedGeneration
      ],
      %{type: :integer}
    )
  end
end
