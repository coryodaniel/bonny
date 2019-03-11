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
  config :mix_test_watch,
    tasks: [
      "test --cover",
      "format",
      "credo"
    ]
end
