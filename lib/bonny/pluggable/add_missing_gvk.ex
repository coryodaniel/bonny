defmodule Bonny.Pluggable.AddMissingGVK do
  @moduledoc """
  The Kubernetes API sometimes doesn't set the fields `apiVersion` and `kind` on
  items of a list operation. E.g. if you use `K8s.Client` to get a list of
  deployments, the deployments won't contains those two fields. This is being
  discussed on https://github.com/kubernetes/kubernetes/issues/3030.

  Bonny sometimes depends on `apiVersion` and `kind` to be defined on the
  resource being handled. This is the case for setting the status, e.g. when
  using `Bonny.Pluggable.SkipObservedGenerations` or `Bonny.Axn.update_status/2`.

  Add this step to your controller in order to set those values on all resources
  being handled.


  ## Examples

      step Bonny.Pluggable.AddMissingGVK,
        apiVersion: "apps/v1",
        kind: "Deployment"
  """

  @behaviour Pluggable

  @impl true
  def init(opts \\ []),
    do: %{
      "apiVersion" => Keyword.fetch!(opts, :apiVersion),
      "kind" => Keyword.fetch!(opts, :kind)
    }

  @impl true
  def call(axn, config) do
    resource = Map.merge(config, axn.resource)
    struct!(axn, resource: resource)
  end
end
