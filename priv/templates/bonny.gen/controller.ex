defmodule <%= app_name %>.Controller.<%= mod_name %> do
  @moduledoc """
  <%= app_name %>: <%= mod_name %> CRD.

  ## Kubernetes CRD Spec

  creates a default CRD from the information it's got, i.e. the module name
  and some variables defined in `config.exs`. You can customize them by
  implementing the  `customize_crd/1` callback:

  ### Examples

  The crd you get as an argument to `customize_crd/1 is already a valid CRD.
  This means you don't have to pass all the fields to `struct!()`, just the
  ones you want to override.

  ```
  @impl Bonny.ControllerV2
  def customize_crd(crd) do
    struct!(
      crd,

      # Customizing the group (defaults to what's defined  in config.exs):
      group: "kewl.example.io"

      # Customizing the scope (defaults to :Namespaced):
      scope: :Cluster

      # Customizing the names (defaults to Bonny.CRDV2.kind_to_names("<%= mod_name %>"))
      names: Bonny.CRDV2.kind_to_names("Wheel", ["w]) # => %{singular: "wheel", plural: "wheels", kind: "Wheel", shortNames: ["w"]}

      # Define your own versions (defaults to an auto-generated "v1" version)
      versions: [
        Bonny.CRD.Version.new!(
          name: "v1beta2",
          served: true,
          storage: true,
          schema: %{openAPIV3Schema: %{...}}
        )
      ]
    )
  end
  ```

  ## Add additional printer columns

  In version 1 of this controller, you could define additional printer columns
  as module attributes. Now they are part of your versions array and are defined
  withing the `customize_crd/1` callback.

  ```
  @impl Bonny.ControllerV2
  def customize_crd(crd) do
    additional_printer_columns = [
      %{name: "username", type: "string", jsonPath: ".spec.username"},
      %{name: "connections", type: "integer", jsonPath: ".spec.max_conn", description: "Maximum of simultaneos connections allowed for this user."
      }
    ]
    put_in(crd, [Access.key(:versions), Access.at(0), Access.key(:additionalPrinterColumns)], additional_printer_columns)
  end

  ```

  ## Declare RBAC permissions used by this module

  RBAC rules can be declared by passing them as options to the `use` statement and generated using `mix bonny.manifest`.

  ### Examples

  ```
  use Bonny.ControllerV2,
    # rbac_rule: {apiGroup, resources_list, verbs_list}
    rbac_rule: {"", ["pods", "secrets"], ["*"]},
    rbac_rule: {"apiextensions.k8s.io", ["foo"], ["*"]}
  """

  use Bonny.ControllerV2
    # rbac_rule: {"", ["pods", "secrets"], ["*"]}

  @doc """
  Handles an `ADDED` or `MODIFIED` event.
  It is also called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec apply(map()) :: :ok | :error
  @impl Bonny.ControllerV2
  def apply(%{} = resource) do
    IO.inspect(resource)
    :ok
  end

  @doc """
  Handles a `DELETED` event
  """
  @spec delete(map()) :: :ok | :error
  @impl Bonny.ControllerV2
  def delete(%{} = resource) do
    IO.inspect(resource)
    :ok
  end
end
