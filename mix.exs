defmodule Bonny.MixProject do
  use Mix.Project

  def project do
    [
      app: :bonny,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Bonny.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:kazan, "~> 0.10"},
      # {:kazan, path: "/Users/coryodaniel/Workspace/coryodaniel/kazan"},
      {:kazan, github: "obmarg/kazan", branch: "feature/custom-oai-specs"},
      # {:poison, "~>4.0"},
      # {:httpotion, "~>3.1"},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false}
    ]
  end
end
