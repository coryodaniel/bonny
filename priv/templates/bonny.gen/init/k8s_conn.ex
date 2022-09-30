defmodule <%= assigns[:app_name] %>.K8sConn do
  @moduledoc """
  Initializes the %K8s.Conn{} struct depending on the mix environment. To be used in config.exs (bonny.exs):

  ```
  # Function to call to get a K8s.Conn object.
  # The function should return a %K8s.Conn{} struct or a {:ok, %K8s.Conn{}} tuple
  get_conn: {<%= assigns[:app_name] %>.K8sConn, :get, [Mix.env()]},
  ```
  """

  @spec get(atom()) :: K8s.Conn.t()
  def get(:dev), do: K8s.Conn.from_file("~/.kube/config", context: "docker-desktop")
  def get(:test), do:
    %K8s.Conn{
      discovery_driver: K8s.Discovery.Driver.File,
      discovery_opts: [config: "test/support/discovery.json"],
      http_provider: K8s.Client.DynamicHTTPProvider
    }
  def get(_), do: K8s.Conn.from_service_account()
end
