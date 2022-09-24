# credo:disable-for-this-file
defmodule DeploymentEventLogController do
  @moduledoc """
  This is a goofy config, but it makes this work in dev w/o having to POST an Example CRD.

  This controller simply logs lifecycle events on Deployments.
  """
  require Logger
  use Bonny.ControllerV2,
    api_definition: %Bonny.API.Definition{group: "apps", resource_type: "deployments", version: "v1"}

  @impl true
  def customize_crd(crd) do
    struct!(crd, [
      names: Bonny.API.CRD.kind_to_names("Deployment"),
      group: "apps"
    ])
  end

  @impl true
  def reconcile(resource) do
    track_event(:reconcile, resource)
  end

  @impl true
  def add(resource) do
    track_event(:add, resource)
  end

  @impl true
  def modify(resource) do
    track_event(:modify, resource)
  end

  @impl true
  def delete(resource) do
    track_event(:delete, resource)
  end

  def track_event(type, resource) do
    Logger.info("#{type}: #{inspect(resource)}")
  end
end
