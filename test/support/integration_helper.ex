defmodule Bonny.Test.IntegrationHelper do
  @moduledoc "Kubernetes integration helpers for test suite"

  @test_resource """
  apiVersion: example.com/v1
  kind: TestResource
  metadata:
    namespace: default
  spec: {}
  """

  @test_resource_v2 """
  apiVersion: example.com/v1
  kind: TestResourceV2
  metadata:
    namespace: default
  spec: {}
  """

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

  @spec delete_test_resource(binary()) :: map()
  def delete_test_resource(name) do
    %{
      "apiVersion" => "example.com/v1",
      "kind" => "TestResource",
      "metadata" => %{"namespace" => "default", "name" => name}
    }
  end

  @spec delete_test_resource_v2(binary()) :: map()
  def delete_test_resource_v2(name) do
    %{
      "apiVersion" => "example.com/v1",
      "kind" => "TestResourceV2",
      "metadata" => %{"namespace" => "default", "name" => name}
    }
  end

  @spec create_test_resource(binary(), pid(), reference()) :: map()
  def create_test_resource(name, pid, ref) do
    @test_resource
    |> YamlElixir.read_from_string!()
    |> put_in(["metadata", "name"], name)
    |> put_in(["spec", "pid"], pid |> :erlang.pid_to_list() |> List.to_string())
    |> put_in(["spec", "ref"], ref |> :erlang.ref_to_list() |> List.to_string())
  end

  @spec create_test_resource_v2(binary(), pid(), reference()) :: map()
  def create_test_resource_v2(name, pid, ref) do
    @test_resource_v2
    |> YamlElixir.read_from_string!()
    |> put_in(["metadata", "name"], name)
    |> put_in(["spec", "pid"], pid |> :erlang.pid_to_list() |> List.to_string())
    |> put_in(["spec", "ref"], ref |> :erlang.ref_to_list() |> List.to_string())
  end
end
