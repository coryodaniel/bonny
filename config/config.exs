use Mix.Config

if Mix.env() == :test do
  config :logger, level: :error

  config :bella,
    k8s_client: Bella.K8sMockClient,
    controllers: [Widget, Cog],
    group: "example.com",
    cluster_name: :test,
    api_version: "apiextensions.k8s.io/v1beta1"
end

if Mix.env() == :dev do
  config :logger, level: :debug

  config :mix_test_watch,
    tasks: [
      "test --cover",
      "format",
      "credo"
    ]
end
