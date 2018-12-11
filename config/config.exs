use Mix.Config

if Mix.env() == :test do
  config :logger, level: :error

  config :bonny,
    crds: [Widget, Cog],
    kubeconf_file: "./test/support/kubeconfig.yaml"
end

if Mix.env() == :dev do
  config :mix_test_watch,
    tasks: [
      "test",
      "format"
      # "test --cover",
      # "format",
      # "credo",
      # "dialyzer"
    ]
end
