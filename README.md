![Bonny](./assets/banner.png "Bonny")

[![Module Version](https://img.shields.io/hexpm/v/bonny.svg)](https://hex.pm/packages/bonny)
[![Coverage Status](https://coveralls.io/repos/github/coryodaniel/bonny/badge.svg?branch=master)](https://coveralls.io/github/coryodaniel/bonny?branch=master)
[![Last Updated](https://img.shields.io/github/last-commit/coryodaniel/bonny.svg)](https://github.com/coryodaniel/bonny/commits/master)

[![Build Status CI](https://github.com/coryodaniel/bonny/actions/workflows/ci.yaml/badge.svg)](https://github.com/coryodaniel/bonny/actions/workflows/ci.yaml)
[![Build Status Elixir](https://github.com/coryodaniel/bonny/actions/workflows/elixir_matrix.yaml/badge.svg)](https://github.com/coryodaniel/bonny/actions/workflows/elixir_matrix.yaml)
[![Build Status K8s](https://github.com/coryodaniel/bonny/actions/workflows/k8s_matrix.yaml/badge.svg)](https://github.com/coryodaniel/bonny/actions/workflows/k8s_matrix.yaml)

[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/bonny/)
[![Total Download](https://img.shields.io/hexpm/dt/bonny.svg)](https://hex.pm/packages/bonny)
[![License](https://img.shields.io/hexpm/l/bonny.svg)](https://github.com/coryodaniel/bonny/blob/master/LICENSE)

# Bonny: Kubernetes Development Framework

Extend the Kubernetes API with Elixir.

Bonny make it easy to create Kubernetes Operators, Controllers, and Custom [Schedulers](./lib/bonny/server/scheduler.ex).

If Kubernetes CRDs and controllers are new to you, read up on the [terminology](#terminology).

## Getting Started

Kickstarting your first controller with bonny is very straight-forward. Bonny
comes with some handy mix tasks to help you.

```
mix new your_operator
```

Now add bonny to your dependencies in `mix.exs`

```elixir
def deps do
  [
    {:bonny, "~> 1.0"}
  ]
end
```

Install dependencies and initialize bonny. This task will ask you
to answer a few questions about your operator.

Refer to the [kubernetes docs](https://kubernetes.io/docs/concepts/overview/kubernetes-api/#api-groups-and-versioning) for
API group and API version.

```
mix deps.get
mix bonny.init
```

**Don't forget to add the generated operator module to your application supervisor.**

### Configuration

`mix bonny.init` creates a configuration file `config/bonny.exs` and imports it to `config/config.exs` for you.

#### Configuring Bonny

Configuring bonny is necessary for the manifest generation through `mix bonny.gen.manifest`.

```elixir

config :bonny,
  # Function to call to get a K8s.Conn object.
  # The function should return a %K8s.Conn{} struct or a {:ok, %K8s.Conn{}} tuple
  get_conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "docker-for-desktop"]]},

  # Set the Kubernetes API group for this operator.
  # This can be overwritten using the @group attribute of a controller
  group: "your-operator.example.com",

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to hyphenated mix app name
  operator_name: "your-operator",

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to hyphenated mix app name
  service_account_name: "your-operator",

  # Labels to apply to the operator's resources.
  labels: %{
    "kewl": "true"
  },

  # Operator deployment resources. These are the defaults.
  resources: %{
    limits: %{cpu: "200m", memory: "200Mi"},
    requests: %{cpu: "200m", memory: "200Mi"}
  }
```

## Running outside of a cluster

Running an operator outside of Kubernetes is not recommended for production use, but can be very useful when testing.

To start your operator and connect it to an existing cluster, one must first:

1. Have configured your operator. The above example is a good place to start.
2. Have some way of connecting to your cluster. The most common is to connect using your kubeconfig as in the example:

```elixir
# config.exs
config :bonny,
  get_conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "optional-alternate-context"]]}
```

If you've used `mix bonny.init` to generate your config, it created a `YourOperator.Conn` module for you. You can edit that instead.

3. If RBAC is enabled, you must have permissions for creating and modifying `CustomResourceDefinition`, `ClusterRole`, `ClusterRoleBinding` and `ServiceAccount`.
4. Generate a manifest `mix bonny.gen.manifest` and install it using kubectl `kubectl apply -f manifest.yaml`

Now you are ready to run your operator

```shell
iex -S mix
```

## Guides

Have a look at the guides that come with this repository. Some can even be opened as a livebook.

- [Mix Tasks](guides/mix_tasks.md)
- [The Operator](guides/the_operator.livemd)
- [Controllers](guides/controllers.livemd)
- [Testing Controllers](guides/testing.livemd)
- [CRD Versions](guides/crd_versions.livemd)
- [Migrations](guides/migrations.md)
- [Contributing](guides/contributing.md)

## Talks

- Commandeering Kubernetes @ The Big Elixir 2019
  - [slides](https://speakerdeck.com/coryodaniel/commandeering-kubernetes-with-elixir)
  - [source code](https://github.com/coryodaniel/talks/tree/master/commandeering)
  - [video](https://www.youtube.com/watch?v=0r9YmbH0xTY)

## Example Operators built with this version of Bonny

- [Kompost](https://github.com/mruoss/kompost) - Providing self-service management of resources for devs

## Example Operators built with an older version of Bonny

- [Eviction Operator](https://github.com/bonny-k8s/eviction_operator) - Bonny v 0.4
- [Hello Operator](https://github.com/coryodaniel/hello_operator) - Bonny v 0.4
- [Todo Operator](https://github.com/bonny-k8s/todo-operator) - Bonny v 0.4

## Telemetry

Bonny uses the `telemetry` to emit event metrics.

Events: `Bonny.Sys.Telemetry.events()`

```elixir
[
    [:reconciler, :reconcile, :start],
    [:reconciler, :reconcile, :stop],
    [:reconciler, :reconcile, :exception],
    [:watcher, :watch, :start],
    [:watcher, :watch, :stop],
    [:watcher, :watch, :exception],
    [:scheduler, :binding, :start],
    [:scheduler, :binding, :stop],
    [:scheduler, :binding, :exception],
    [:task, :execution, :start],
    [:task, :execution, :stop],
    [:task, :execution, :exception],
]
```

## Terminology

_[Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-resources)_:

> A custom resource is an extension of the Kubernetes API that is not necessarily available on every Kubernetes cluster. In other words, it represents a customization of a particular Kubernetes installation.

_[CRD Custom Resource Definition](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#customresourcedefinitions)_:

> The CustomResourceDefinition API resource allows you to define custom resources. Defining a CRD object creates a new custom resource with a name and schema that you specify. The Kubernetes API serves and handles the storage of your custom resource.

_[Controller](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-controllers)_:

> A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

_[Operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)_:

A set of application specific controllers deployed on Kubernetes and managed via kubectl and the Kubernetes API.

## Contributing

I'm thankful for any contribution to this project. Check out the [contribution guide](guides/contributing.md)

## Operator Blog Posts

- [Why Kubernetes Operators are a game changer](https://blog.couchbase.com/kubernetes-operators-game-changer/)
