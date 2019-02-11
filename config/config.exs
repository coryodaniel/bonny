use Mix.Config

if Mix.env() == :test do
  config :logger, level: :error

  config :bonny,
    controllers: [Widget, Cog],
    group: "example.com",
    cluster_name: :test

  config :k8s,
    clusters: %{
      test: %{
        conf: "./test/support/kubeconfig.yaml"
      }
    }
end

if Mix.env() == :dev do
  config :mix_test_watch,
    tasks: [
      "test --cover",
      "format",
      "credo"
    ]
end
