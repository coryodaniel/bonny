defmodule <%= app_name %>.Controller.<%= controller_name %> do
  @moduledoc """
  <%= app_name %>: <%= controller_name %> controller.

  ## Controlled Resource

  You have to pass the option `for_resource` to `use Bonny.ControllerV2`.
  `for_resource` should be either a `%Bonny.API.CRD{}` struct or a
  `%Bonny.API.ResourceEndpoint` struct.

  ### Examples

  ```
  use Bonny.ControllerV2,
    for_resource:
      %Bonny.API.CRD{
        group: "example.com",
        names: Bonny.API.CRD.kind_to_names("CronTab"),
        versions: [MyController.API.CronTab.V1],
      }
  ```

  ```
  use Bonny.ControllerV2,
    for_resource:
      %Bonny.API.ResourceEndpoint{
        group: "apps",
        version: "v1",
        resource_type: "deployments",
      }
  ```

  ## Declare RBAC permissions used by this module

  RBAC rules can be declared via the `rbac_rule/1` macro and generated using `mix bonny.manifest`.

  ### Examples

  ```
  # rbac_rule({apiGroup, resources_list, verbs_list})
  rbac_rule({"", ["pods", "secrets"], ["*"]})
  rbac_rule({"apiextensions.k8s.io", ["foo"], ["*"]})
  ```
  """

  <%= if with_crd do %>
  require Bonny.API.CRD
  <% end %>

  use Bonny.ControllerV2,
    for_resource: <%= if with_crd do %>
      Bonny.API.CRD.build_for_controller!(
        names: Bonny.API.CRD.kind_to_names("<%= crd_name %>"),
      )<% else %>
      <%= inspect(resource_endpoint) %><% end %>,
    # check the controller guide for an explanation on skip_observed_generations.
    # If you enable skip_observed_generations, make sure to regenerate your manifest!
    skip_observed_generations: false

  @doc """
  Handles a `ADDED` event.
  """
  @impl Bonny.ControllerV2
  @spec add(Bonny.Resource.t()) :: :ok | :error
  def add(%{} = resource), do: apply(resource)

  @doc """
  Handles a `MODIFIED` event
  """
  @impl Bonny.ControllerV2
  @spec modify(Bonny.Resource.t()) :: :ok | :error
  def modify(%{} = resource), do: apply(resource)

  @doc """
  Handles a `DELETED` event
  """
  @impl Bonny.ControllerV2
  @spec delete(Bonny.Resource.t()) :: :ok | :error
  def delete(%{} = resource) do
    IO.inspect(resource)
    :ok
  end

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @impl Bonny.ControllerV2
  @spec reconcile(Bonny.Resource.t()) :: :ok | :error
  def reconcile(%{} = resource) do
    IO.inspect(resource)
    :ok
  end

  # We suggest you create a declarative operator where `add/1` and `modify/1`
  # both perform the same operation, i.e. enforce the state requested
  # by the created/modified resource.
  # Feel free to change this behaviour if it doesn't fit your purpose.
  defp apply(resource) do
    IO.inspect(resource)
    :ok
  end
end
