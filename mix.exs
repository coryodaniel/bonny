defmodule Bonny.MixProject do
  use Mix.Project
  @version "1.0.0"
  @source_url "https://github.com/coryodaniel/bonny"

  def project do
    [
      app: :bonny,
      description: description(),
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: cli_env(),
      docs: docs(),
      package: package(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix, :eex, :owl]],
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
      {:inflex, "~> 2.0"},
      {:jason, "~> 1.1"},
      # {:k8s, "~> 2.0"},
      {:k8s, "~> 2.0"},
      {:owl, "~> 0.6.0", runtime: false},
      {:pluggable, "~> 1.0"},
      {:telemetry, "~> 1.0"},
      {:ymlr, "~> 3.0"},

      # Dev deps
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2.0", only: [:dev, :test], runtime: false},
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
      maintainers: ["Cory O'Daniel", "Michael Ruoss"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md",
        "GitHub" => @source_url
      },
      files: ["lib", "mix.exs", "priv", "README.md", "LICENSE", "CHANGELOG.md"]
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "assets/bonny.png",
      assets: "assets",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/contributing.md",
        "guides/controllers.livemd",
        "guides/crd_versions.livemd",
        "guides/migrations.md",
        "guides/mix_tasks.md",
        "guides/testing.livemd",
        "guides/the_operator.livemd"
      ],
      groups_for_extras: [
        Guides: Path.wildcard("guides/*.md")
      ]
    ]
  end

  defp description do
    """
    Bonny: Kubernetes Operator Development Framework. Extend Kubernetes with Elixir
    """
  end
end
