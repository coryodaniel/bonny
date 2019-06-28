defmodule Bonny.Server.Scheduler.Binding do
  @moduledoc """
  Kubernetes [binding](#placeholder) interface.

  Currently [undocumented](https://github.com/kubernetes/kubernetes/issues/75749) in Kubernetes docs.

  ## Links
  * [Example using curl](https://gist.github.com/kelseyhightower/2349c9c645d32a3fcbe385082de74668)
  * [Example using golang](https://banzaicloud.com/blog/k8s-custom-scheduler/)

  """

  @json_headers [{"Accept", "application/json"}, {"Content-Type", "application/json"}]

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
  Performs a POST HTTP request against the pod's binding subresource.

  `/api/v1/namespaces/{NAMESPACE}/pods/{POD}/binding`
  """

  @spec create(map, atom) :: {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  def create(binding, cluster) do
    pod_name = K8s.Resource.name(binding)
    pod_namespace = K8s.Resource.namespace(binding)
    node_name = get_in(binding, ["target", "name"])
    operation = K8s.Operation.build(:get, "v1", :pod, namespace: pod_namespace, name: pod_name)

    with {:ok, base_url} <- K8s.Cluster.url_for(operation, cluster),
         {:ok, cluster_connection_config} <- K8s.Cluster.conf(cluster),
         {:ok, request_options} <- K8s.Conf.RequestOptions.generate(cluster_connection_config),
         {:ok, body} <- Jason.encode(binding),
         headers <- request_options.headers ++ @json_headers,
         options <- [ssl: request_options.ssl_options] do
      metadata = %{pod_name: pod_name, pod_namespace: pod_namespace, node_name: node_name}

      {measurements, response} =
        Bonny.Sys.Event.measure(HTTPoison, :post, ["#{base_url}/binding", body, headers, options])

      case response do
        {:ok, body} ->
          Bonny.Sys.Event.scheduler_binding_succeeded(measurements, metadata)
          {:ok, body}

        {:error, error} ->
          Bonny.Sys.Event.scheduler_binding_failed(measurements, metadata)
          {:error, error}
      end
    end
  end
end
