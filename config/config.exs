import Config

if config_env() == :test do
  config :logger, level: :none

  config :k8s,
    discovery_driver: K8s.Discovery.Driver.File,
    discovery_opts: [config: "test/support/discovery/tests.json"],
    http_provider: K8s.Client.DynamicHTTPProvider

  config :bonny,
    controllers: [
      Widget,
      Cog,
      V1.Whizbang,
      TestResource,
      TestResourceV2Controller,
      TestResourceV3Controller,
      ConfigMapController
    ],
    group: "example.com",
    versions: [Bonny.Test.API.V1],
    get_conn: {Bonny.K8sMock, :conn},
    api_version: "apiextensions.k8s.io/v1",
    manifest_override_callback: &Mix.Tasks.Bonny.Gen.Manifest.TestCustomizer.override/1
end

if config_env() == :dev do
  config :logger, level: :debug

  config :mix_test_watch,
    tasks: [
      "test --cover",
      "format",
      "credo"
    ]

  config :bonny,
    get_conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "k3d-k8s-ex"]]},
    versions: [Bonny.API.V1],
    controllers: [
      DeploymentEventLogController,
      TestScheduler
    ]

  # config :elixir, :dbg_callback, {Macro, :dbg, []}
end
