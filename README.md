![Bonny](./assets/banner.png "Bonny")

[![Build Status](https://travis-ci.org/coryodaniel/bonny.svg?branch=master)](https://travis-ci.org/coryodaniel/bonny)
[![Coverage Status](https://coveralls.io/repos/github/coryodaniel/bonny/badge.svg?branch=master)](https://coveralls.io/github/coryodaniel/bonny?branch=master)
[![Module Version](https://img.shields.io/hexpm/v/bonny.svg)](https://hex.pm/packages/bonny)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/bonny/)
[![Total Download](https://img.shields.io/hexpm/dt/bonny.svg)](https://hex.pm/packages/bonny)
[![License](https://img.shields.io/hexpm/l/bonny.svg)](https://github.com/coryodaniel/bonny/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/coryodaniel/bonny.svg)](https://github.com/coryodaniel/bonny/commits/master)

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
    {:bonny, "~> 0.5"}
  ]
end
```

Install dependencies and initialize bonny. This task will ask you
to answer a few questions about your controller

Refer to the [kubernetes docs](https://kubernetes.io/docs/concepts/overview/kubernetes-api/#api-groups-and-versioning) for
API group and API version.

```
mix deps.get
mix bonny.init
```

Now you can generate your controllers.

```
mix bonny.gen.controller
```

Again, you'll be asked questions regarding your controller. Refer to the [controllers guide](guides/controllers.livemd) for further information.

Don't forget to add your controller to the list of controllers in `config/bonny.exs`

### Configuration

`mix bonny.init` creates a configuration file `config/bonny.exs` and imports it to `config/config.exs` for you.

#### Configuring Bonny

Bonny uses the [k8s client](https://github.com/coryodaniel/k8s) under the hood.

The only configuration parameters required are `:bonny` `controllers` and a `:get_conn` callback (Note: this file will not exist unless you created it using `mix bonny.init`):

```elixir

config :bonny,
  # Add each Controller module for this operator to load here
  # Defaults to none. This *must* be set.
  controllers: [
    MyApp.Controllers.WebServer,
    MyApp.Controllers.Database,
    MyApp.Controllers.Memcached
  ],

  # Function to call to get a K8s.Conn object.
  # The function should return a %K8s.Conn{} struct or a {:ok, %K8s.Conn{}} tuple
  get_conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "docker-for-desktop"]]},

  # The API version of the CRD.
  # Defaults to "apiextensions.k8s.io/v1beta1" which is not supported
  # by newer versions of Kubernetes anymore.
  api_version: "apiextensions.k8s.io/v1",

  # The namespace to watch for Namespaced CRDs.
  # Defaults to "default". `:all` for all namespaces
  # Also configurable via environment variable `BONNY_POD_NAMESPACE`
  namespace: "default",

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
  {K8s.Conn, :from_file, ["~/.kube/config", [context: "optional-alternate-context"]]}
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
- [Controllers](guides/controllers.livemd)
- [CRD Versions](guides/crd_versions.livemd)
- [Migrations](guides/migrations.md)
- [Contributing](guides/contributing.md)

## Tutorials and Examples:

_Important!_ These tutorials are for an older version of Bonny, but the `add/1`, `modify/1`, and `delete/1` APIs are the same, as well as a new `reconcile/1` function. Additionally a [k8s](https://github.com/coryodaniel/k8s) has been added!

Feel free to message me on [twitter](https://twitter.com/coryodaniel) if you need any help!

- HelloOperator Tutorial Part: [1](https://medium.com/coryodaniel/bonny-extending-kubernetes-with-elixir-part-1-34ccb2ea0b4d) [2](https://medium.com/coryodaniel/bonny-extending-kubernetes-with-elixir-part-2-efdf8e422085) [3](https://medium.com/coryodaniel/bonny-extending-kubernetes-with-elixir-part-3-fdfc8b8cc843)
- HelloOperator [source code](https://github.com/coryodaniel/hello_operator)

## Talks

- Commandeering Kubernetes @ The Big Elixir 2019
  - [slides](https://speakerdeck.com/coryodaniel/commandeering-kubernetes-with-elixir)
  - [source code](https://github.com/coryodaniel/talks/tree/master/commandeering)
  - [video](https://www.youtube.com/watch?v=0r9YmbH0xTY)

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

## Testing

Check the guide about testing

## Operator Blog Posts

- [Why Kubernetes Operators are a game changer](https://blog.couchbase.com/kubernetes-operators-game-changer/)
