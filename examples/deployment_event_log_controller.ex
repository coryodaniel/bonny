# credo:disable-for-this-file
defmodule DeploymentEventLogController do
  @moduledoc """
  This is a goofy config, but it makes this work in dev w/o having to POST an Example CRD.

  This controller simply logs lifecycle events on Deployments.
  """
  require Logger
  use Bella.Controller

  @impl true
  def reconcile_operation() do
    K8s.Client.list("reconciler.test.foos/v1", :foos)
  end

  @impl true
  def watch_operation() do
    K8s.Client.list("watcher.test/v1", :foos)
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
