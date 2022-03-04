defmodule Bonny.Server.Scheduler.Binding do
  @moduledoc """
  Kubernetes [binding](#placeholder) interface.

  Currently [undocumented](https://github.com/kubernetes/kubernetes/issues/75749) in Kubernetes docs.

  ## Links
  * [Example using curl](https://gist.github.com/kelseyhightower/2349c9c645d32a3fcbe385082de74668)
  * [Example using golang](https://banzaicloud.com/blog/k8s-custom-scheduler/)

  """

  require Logger

  @doc """
  Returns a map representing a `Binding` kubernetes resource

  ## Example
      iex> pod = %{"metadata" => %{"name" => "nginx", "namespace" => "default"}}
      ...> node = %{"metadata" => %{"name" => "kewl-node"}}
      iex> Bonny.Server.Scheduler.Binding.new(pod, node)
      %{"apiVersion" => "v1", "kind" => "Binding", "metadata" => %{"name" => "nginx", "namespace" => "default"}, "target" => %{"apiVersion" => "v1", "kind" => "Node", "name" => "kewl-node"}}
  """
  @spec new(map(), map()) :: map()
  def new(pod, node) do
    pod_name = K8s.Resource.name(pod)
    pod_namespace = K8s.Resource.namespace(pod)
    node_name = K8s.Resource.name(node)

    %{
      "apiVersion" => "v1",
      "kind" => "Binding",
      "metadata" => %{
        "name" => pod_name,
        "namespace" => pod_namespace
      },
      "target" => %{
        "apiVersion" => "v1",
        "kind" => "Node",
        "name" => node_name
      }
    }
  end

  @doc """
  Creates the pod's /binding subresource through K8s.
  """
  @spec create(K8s.Conn.t(), map(), map()) ::
          {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  def create(conn, pod, node) do
    binding = new(pod, node)
    operation = K8s.Client.create(pod, binding)
    metadata = %{operation: operation}

    :telemetry.span([:scheduler, :binding], metadata, fn ->
      case K8s.Client.run(conn, operation) do
        {:ok, body} ->
          Logger.debug("Schduler binding succeeded", metadata)
          {{:ok, body}, metadata}

        {:error, error} ->
          metadata = Map.put(metadata, :error, error)
          Logger.error("Schduler binding failed", metadata)
          {{:error, error}, metadata}
      end
    end)
  end
end
