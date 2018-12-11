use Mix.Config

# if Mix.env() == :test do
  config :logger, :console, level: :info
  config :kazan, :server, :in_cluster
  config :kazan,
    oai_name_mappings: [
      {"something.test", Test.Bonny},
      {"widgets.bonny", Test.Bonny},
      {"com.coryodaniel", Test.Bonny}
    ]
# end
