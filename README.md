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

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/bonny](https://hexdocs.pm/bonny).

## Notes

```elixir
config :bonny, 
  crds: [Widget, Cog],
  kubeconf_file: "path/to/kube/config",
  kubeconf_opts: [
    user: "other-user",
    context: "...",
    cluster": "..."
  ]
  # Only used if the CRDs are `namespaced`
  # override_namespace: nil
  # defaults to Env var "BONNY_POD_NAMESPACE"
```

If no config file is given, bonny will default to the service account on the pod

K8s.Conf.from_file(path, opts)
K8s.Conf.from_service_account

## Starting a test iex session

```elixir
BONNY_CONFIG_FILE=~/.kube/config MIX_ENV=test iex -S mix
```
