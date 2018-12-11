defmodule Bonny.CRD do
  @moduledoc """
  Kubernetes [CustomResourceDefinition](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/)
  """
  alias Bonny.CRD

  @crd_version "apiextensions.k8s.io/v1beta1"

  @type names_t :: %{
          kind: String.t(),
          singular: String.t(),
          plural: String.t(),
          short_names: nil | list(String.t()),
          version: String.t()
        }

  @typedoc "CRD Spec"
  @type t :: %__MODULE__{
          scope: :namespaced | :cluster,
          group: String.t(),
          names: names_t,
          version: String.t()
        }

  @enforce_keys [:scope, :group, :names]
  defstruct scope: :namespaced,
            group: nil,
            names: nil,
            version: nil

  @doc """
  URL Path to list a CRD's resources

  *Namespaced CRD URL Path*
  /apis/bonny.example.om/v1/namespaces/default/widgets

  *Cluster Resource URL Path & `--all-namespaces` path*
  /apis/bonny.example.io/v1/widgets
  """
  @spec list_path(Bonny.CRD.t()) :: binary
  def list_path(crd = %CRD{}), do: base_path(crd)

  @spec watch_path(Bonny.CRD.t(), String.t() | integer) :: binary
  def watch_path(crd = %CRD{}, resource_version) do
    "#{base_path(crd)}?resourceVersion=#{resource_version}&watch=true"
  end

  @doc """
  URL path to read the specified CustomResourceDefinition

  *Namespaced CRD Resource URL Path*
  /apis/bonny.example.io/v1/namespaces/default/widgets/test-widget

  *Cluster CRD Resource URL Path & `--all-namespaces` path*
  /apis/bonny.example.io/v1/widgets/test-widget
  """
  @spec read_path(Bonny.CRD.t(), String.t()) :: binary
  def read_path(crd = %CRD{}, name) do
    "#{base_path(crd)}/#{name}"
  end

  defp base_path(%CRD{
         scope: :namespaced,
         version: version,
         group: group,
         names: %{plural: plural}
       }) do
    "/apis/#{group}/#{version}/namespaces/#{Bonny.namespace()}/#{plural}"
  end

  defp base_path(%CRD{scope: :cluster, version: version, group: group, names: %{plural: plural}}) do
    "/apis/#{group}/#{version}/#{plural}"
  end
end
