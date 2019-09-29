use Mix.Config

if Mix.env() == :test do
  config :logger, level: :error

  config :bonny,
    k8s_client: Bonny.K8sMockClient,
    controllers: [Widget, Cog],
    group: "example.com",
    cluster_name: :test
end

if Mix.env() == :dev do
  config :logger, level: :debug

  config :mix_test_watch,
    tasks: [
      "test --cover",
      "format",
      "credo"
    ]

  config :k8s,
    clusters: %{
      dev: %{
        conn: "~/.kube/config",
        conn_opts: [context: "docker-for-desktop"]
      }
    }

  config :bonny,
    cluster_name: :dev,
    controllers: [
      DeploymentEventLogController
    ]
end
