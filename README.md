![Bonny](./banner.png "Bonny")


[![Build Status](https://travis-ci.org/coryodaniel/bonny.svg?branch=master)](https://travis-ci.org/coryodaniel/bonny)
[![Coverage Status](https://coveralls.io/repos/github/coryodaniel/bonny/badge.svg?branch=master)](https://coveralls.io/github/coryodaniel/bonny?branch=master)
[![Hex.pm](http://img.shields.io/hexpm/v/bonny.svg?style=flat)](https://hex.pm/packages/bonny)
![Hex.pm](https://img.shields.io/hexpm/l/bonny.svg?style=flat)

# Bonny

Kubernetes Operator SDK written in Elixir. 

Extend the Kubernetes API and implement CustomResourceDefinitions lifecycles in Elixir.

If Kubernetes CRDs and controllers are new to you, read up on the [terminology](#terminology).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bonny` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bonny, "~> 0.1"}
  ]
end
```

Add to `config.exs`:

```elixir
config :bonny, 
  # Add each CRD Controller module for this operator to load here
  controllers: [
    MyApp.Controllers.V1.WebServer,
    MyApp.Controllers.V1.Database,
    MyApp.Controllers.V1.Memcached
  ],
  
  # Set the Kubernetes API group for this operator.
  # This can be overwritten using the @group attribute of a controller
  group: "your-operator.your-domain.tld", 

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to "bonny"
  operator_name: "your-operator",

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to operator name
  service_account_name: "your-operator",

  # Labels to apply to the operator's resources.
  labels: %{
    "kewl": "true"
  }

  # Kubernetes YAML config, defaults to the service account of the pod
  kubeconf_file: "",
  
  # Defaults to "current-context" if a config file is provided, override user, cluster. or context here
  kubeconf_opts: []
```

## Bonny Generators

There are a number of generators to help create a kubernetes operator.

`mix help | grep bonny`

### Generating an operator controller

An operator can have multiple controllers. Each controller handles the lifecycle of a custom resource.

By default controllers are generated in the `V1` version scope.

```shell
mix bonny.gen.controller Widget widgets
```

You can specify the version flag to create a new version of a controller. Bonny will dispatch the controller for the given version. So old versions of resources can live alongside new versions.

```shell
mix bonny.gen.controller Widget widgets --version v2alpha1
```

*Note:* The one restriction with versions is that they will be camelized into a module name.

Open up your controller and add functionality for your resoures lifecycle:

* Add
* Modify
* Delete

Each controller can create multiple resources. 

For example, a *todo app* controller could deploy a `Deployment` and a `Service`.

Your operator can also have multiple controllers if you want to support multiple resources in your operator!

Check out the two test controllers:

* [Cog](./test/support/cog.ex)
* [Widget](./test/support/widget.ex)

### Generating a dockerfile

The following command will generate a dockerfile *for your operator*. This will need to be pushed to a docker repository that your kubernetes cluster can access.

Again, this Dockerfile is for your operator, not for the pods your operator may deploy.

```shell
mix bonny.gen.dockerfile

export BONNY_IMAGE=YOUR_IMAGE_NAME_HERE
docker build -t ${BONNY_IMAGE} .
docker push ${BONNY_IMAGE}:latest
```

### Generating Kubernetes manifest for operator

This will generate the entire manifest for this operator including:

* CRD manifests
* RBAC
* Service Account
* Operator Deployment

The operator manifest generator requires the `image` flag to be passed. This is the docker image URL of your operators docker image created by `mix bonny.gen.docker` above.

```shell
mix bonny.gen.manifest --image ${BONNY_IMAGE}
```

**Note:** YAML output is JSON formatted YAML. Sorry, elixirland isn't fond of YAML :D

By default the manifest will generate the service account and deployment in the "default" namespace.

*To set the namespace explicitly:*

```shell
mix bonny.gen.manifest --out - -n test
```

*Alternatively you can apply it directly to kubectl*:

```shell
mix bonny.gen.manifest --out - -n test | kubectl apply -f - -n test
```

### Generating a resource

TODO: Need to support validation / OpenAPI.

## Terminology

*[Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-resources)*: 

> A custom resource is an extension of the Kubernetes API that is not necessarily available on every Kubernetes cluster. In other words, it represents a customization of a particular Kubernetes installation.

*[CRD Custom Resource Definition](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#customresourcedefinitions)*: 

> The CustomResourceDefinition API resource allows you to define custom resources. Defining a CRD object creates a new custom resource with a name and schema that you specify. The Kubernetes API serves and handles the storage of your custom resource.

*[Controller](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-controllers)*:

> A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

*Operator*:

A set of application specific controllers deployed on Kubernetes and managed via kubectl and the Kubernetes API.

## Docs

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/bonny](https://hexdocs.pm/bonny).


## Testing

```elixir
mix test
```

### Starting an interactive test session

This will load two modules in the operator, `Widget` and `Cog`.

**Create the CRDs:**

```shell
kubectl apply -f ./test/support/crd.yaml
```

**Start the session:**

```elixir
BONNY_CONFIG_FILE=~/.kube/config MIX_ENV=test iex -S mix
```

The GenServers wait about 5 seconds to start watching.

**Trigger some events:**

```shell
kubectl apply -f ./test/support/widget.yaml
```

If log level is set to `debug` you will see the events get sent to the pod's logs.


## Operator Blog Posts

* [Why Kubernetes Operators are a game changer](https://blog.couchbase.com/kubernetes-operators-game-changer/)
