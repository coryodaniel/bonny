# Bonny

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bonny` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bonny, "~> 0.1.0"}
  ]
end
```

Add to `config.exs`:

```elixir
config :bonny, 
  # Add each CRD module for this operator to load here
  crds: [],           
  # Kubernetes YAML config, defaults to the service account of the pod
  kubeconf_file: "",
  # Defaults to "current-context" if a config file is provided, override user, cluster. or context here
  kubeconf_opts: []
```

## Bonny Generators

`mix help

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/bonny](https://hexdocs.pm/bonny).

## Starting a test iex session

```elixir
BONNY_CONFIG_FILE=~/.kube/config MIX_ENV=test iex -S mix
```
