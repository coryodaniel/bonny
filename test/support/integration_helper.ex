defmodule Bonny.Test.IntegrationHelper do
  @moduledoc "Kubernetes integration helpers for test suite"

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
end
