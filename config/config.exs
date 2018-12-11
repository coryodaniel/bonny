use Mix.Config

if Mix.env() == :test do
  config :logger, :console, level: :warn
  config :kazan,
    oai_name_mappings: [{"something.test", Test.Bonny}]
end
