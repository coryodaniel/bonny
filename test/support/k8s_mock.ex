# credo:disable-for-this-file
defmodule Bonny.K8sMock do
  def conn(mock \\ nil) do
    #  Have to register the mock here because Bonny uses Task.start() so we won't know the pid when starting the test.
    if mock, do: K8s.Client.DynamicHTTPProvider.register(self(), mock)

    %K8s.Conn{
      discovery_driver: K8s.Discovery.Driver.File,
      discovery_opts: [config: "test/support/discovery/tests.json"],
      http_provider: K8s.Client.DynamicHTTPProvider
    }
  end
end
