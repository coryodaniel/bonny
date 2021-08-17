# Bonny: Kubernetes Controller Framework

Bonny make it easy to create Kubernetes Controllers.

## Installation

Bonny can be installed by adding `bella` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bella, "~> 1.0"}
  ]
end
```

### Configuration

Bonny uses the [k8s client](https://github.com/coryodaniel/k8s) under the hood.

The only configuration parameters required are `:bella` `controllers` and a `:k8s` cluster:

```elixir
config :k8s,
  clusters: %{
    default: %{ # `default` here must match `cluster_name` below
      conn: "~/.kube/config"
    }
  }

  # K8s.Cluster to use, defaults to :default
  cluster_name: :default
```

## Telemetry

Bonny uses the `telemetry` and `notion` library to emit event metrics.

Events: `Bonny.Sys.Event.events()`

```elixir
[
  [:bella, :reconciler, :genserver, :down],
  [:bella, :reconciler, :reconcile, :failed],
  [:bella, :reconciler, :reconcile, :succeeded],
  [:bella, :reconciler, :run, :started],
  [:bella, :reconciler, :fetch, :failed],
  [:bella, :reconciler, :fetch, :succeeded],
  [:bella, :reconciler, :initialized],
  [:bella, :watcher, :genserver, :down],
  [:bella, :watcher, :chunk, :received],
  [:bella, :watcher, :watch, :timedout],
  [:bella, :watcher, :watch, :failed],
  [:bella, :watcher, :watch, :finished],
  [:bella, :watcher, :watch, :succeeded],
  [:bella, :watcher, :watch, :started],
  [:bella, :watcher, :initialized]
]
```

## Terminology

_[Controller](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-controllers)_:

> A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

## Testing

```elixir
mix test
```
