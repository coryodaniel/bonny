defmodule Bonny.MixProject do
  use Mix.Project
  @version "0.4.4"
  @source_url "https://github.com/coryodaniel/bonny"

  def project do
    [
      app: :bonny,
      description: description(),
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: cli_env(),
      docs: docs(),
      package: package(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix, :eex]],
      xref: [exclude: [EEx]]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "examples"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {Bonny.Application, []}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end

  defp cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      "coveralls.travis": :test,
      "coveralls.github": :test,
      "coveralls.xml": :test,
      "coveralls.json": :test
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:k8s, "~> 1.1"},
      {:telemetry, "~> 1.0"},
      #  2.0 only supports Elixir >= 1.11
      {:ymlr, "~> 2.0"},

      # Dev deps
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      # {:ex_doc, "~> 0.23", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},

      # Test deps
      {:excoveralls, "~> 0.14", only: :test}
    ]
  end

  defp package do
    [
      name: :bonny,
      maintainers: ["Cory O'Daniel"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "assets/bonny.png",
      assets: "assets",
      source_ref: @version,
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp description do
    """
    Bonny: Kubernetes Operator Development Framework. Extend Kubernetes with Elixir
    """
  end
end
