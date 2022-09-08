defmodule Bonny.Test.IntegrationHelper do
  @moduledoc "Kubernetes integration helpers for test suite"

  @kinds %{
    v1: "TestResource",
    v2: "TestResourceV2",
    v3: "TestResourceV3"
  }

  @spec conn() :: K8s.Conn.t()
  def conn() do
    {:ok, conn} =
      "TEST_KUBECONFIG"
      |> System.get_env("./integration.yaml")
      |> K8s.Conn.from_file()

    # Override the defaults for testing
    %K8s.Conn{
      conn
      | discovery_driver: K8s.Discovery.Driver.HTTP,
        discovery_opts: [],
        http_provider: K8s.Client.HTTPProvider
    }
  end

  @spec delete_test_resource(binary(), atom()) :: map()
  def delete_test_resource(name, version) do
    %{
      "apiVersion" => "example.com/v1",
      "kind" => @kinds[version],
      "metadata" => %{"namespace" => "default", "name" => name}
    }
  end

  @spec create_test_resource(binary(), atom(), pid(), reference()) :: map()
  def create_test_resource(name, version, pid, ref) do
    """
    apiVersion: example.com/v1
    kind: #{@kinds[version]}
    metadata:
      namespace: default
      name: #{name}
    spec:
      pid: "#{pid |> :erlang.pid_to_list() |> List.to_string()}"
      ref: "#{ref |> :erlang.ref_to_list() |> List.to_string()}"
    """
    |> YamlElixir.read_from_string!()
  end
end
