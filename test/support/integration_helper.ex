defmodule Bonny.Test.IntegrationHelper do
  @moduledoc "Kubernetes integration helpers for test suite"

  alias Bonny.Test.ResourceHelper

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

  @spec create_test_resource(binary(), atom(), pid(), reference(), keyword()) :: map()
  def create_test_resource(name, version, pid, ref, opts \\ []) do
    labels = Keyword.get(opts, :labels, %{})

    """
    apiVersion: example.com/v1
    kind: #{@kinds[version]}
    metadata:
      namespace: default
      name: #{name}
    spec:
      pid: "#{ResourceHelper.pid_to_string(pid)}"
      ref: "#{ResourceHelper.ref_to_string(ref)}"
    """
    |> YamlElixir.read_from_string!()
    |> put_in(~w(metadata labels), labels)
  end
end
