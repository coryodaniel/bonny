defmodule Bella.MixProject do
  use Mix.Project
  @version "1.0.0"
  @source_url "https://github.com/batteries-included/bella"

  def project do
    [
      app: :bella,
      description: description(),
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.travis": :test, "coveralls.html": :test],
      docs: docs(),
      package: package(),
      dialyzer: [plt_add_apps: [:mix, :eex]],
      xref: [exclude: [EEx]]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "examples"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:k8s, "~> 1.0.0"},
      {:notion, "~> 0.2"},
      {:telemetry, ">= 0.4.0"},

      # Dev deps
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:credo_envvar, "~> 0.1", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      # Test deps
      {:excoveralls, "~> 0.12", only: :test}
    ]
  end

  defp package do
    [
      name: :bella,
      maintainers: ["Elliott Clark"],
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
      source_ref: @version,
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp description do
    """
    Bella: Kubernetes Controller Library
    """
  end
end
