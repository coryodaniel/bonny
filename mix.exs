defmodule Bonny.MixProject do
  use Mix.Project

  def project do
    [
      app: :bonny,
      description: description(),
      version: "0.3.3",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.travis": :test, "coveralls.html": :test],
      docs: [
        extras: ["README.md", "CHANGELOG.md"],
        main: "readme"
      ],
      package: package(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix, :eex]]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:jason, "~> 1.1"},
      {:k8s, "~> 0.4"},
      {:notion, "~> 0.2"},
      {:telemetry, ">=  0.4.0"},

      # Dev deps
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.20", only: :dev},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},

      # Test deps
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end

  defp package do
    [
      name: :bonny,
      maintainers: ["Cory O'Daniel"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/coryodaniel/bonny"
      }
    ]
  end

  defp aliases do
    [docs: ["docs", &copy_images/1]]
  end

  defp copy_images(_) do
    File.cp!("./banner.png", "./doc/banner.png")
  end

  defp description do
    """
    Bonny: Kubernetes Operator Development Framework. Extend Kubernetes with Elixir
    """
  end
end
