defmodule Bonny.Server.Scheduler.Binding do
  @moduledoc """
  Kubernetes [binding](#placeholder) interface.

  Currently [undocumented](https://github.com/kubernetes/kubernetes/issues/75749) in Kubernetes docs.

  ## Links
  * [Example using curl](https://gist.github.com/kelseyhightower/2349c9c645d32a3fcbe385082de74668)
  * [Example using golang](https://banzaicloud.com/blog/k8s-custom-scheduler/)

  """

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
  @spec create(map(), atom()) :: {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  def create(pod, node) do
    binding = new(pod, node)
    operation = K8s.Client.create(pod, binding)

    {measurements, response} =
      Bonny.Sys.Event.measure(K8s.Client, :run, [Bonny.Config.conn(), operation])

    case response do
      {:ok, body} ->
        Bonny.Sys.Event.scheduler_binding_succeeded(measurements, pod)
        {:ok, body}

      {:error, error} ->
        Bonny.Sys.Event.scheduler_binding_failed(measurements, pod)
        {:error, error}
    end
  end
end
