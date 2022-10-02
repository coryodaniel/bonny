# Bonny Mix Tasks

There are a number of mix tasks to help create a Kubernetes operator.

`mix help | grep bonny`

## Initialize your Operator (`mix bonny.init`)

To add bonny to your existing elixir project (`mix new your_operator`), this tasks
helps you to generate application configuration and initializing your test suite.

Just run `mix bonny.init`, the task will ask you questions about your operator
and initialize it.

## Controller Generation (`mix bonny.gen.controller`)

Guides you through the creation of a controller. Normally, a controller of an operator
watches a custom resource defined by that same operator. This is the default flow through
this mix task.
However, you can also create a controller that watches and reacts on events of
core resources or custom resources defined by another operator.

See the [controllers guide](controllers.livemd) for further information about controllers.

After the mix task ran through, open up your controller and add functionality for your
resource's lifecycles:

- Apply (or Add/Modify)
- Delete
- Reconcile; periodically called with each every instance of a CRD's resources

Ideally you'd also open up the generated CRD versions and add OpenAPIV3 schema,
additional printer columns, etc.

Your operator can also have multiple controllers if you want to watch multiple
resources in your operator. Just run the mix task again.

### Generating a dockerfile

The following command will generate a dockerfile _for your operator_. This will need to be pushed to a docker repository that your Kubernetes cluster can access.

Again, this Dockerfile is for your operator, not for the pods your operator may deploy.

You can skip this step when developing by running your operator _external_ to the cluster.

```shell
mix bonny.gen.dockerfile

export BONNY_IMAGE=YOUR_IMAGE_NAME_HERE
docker build -t ${BONNY_IMAGE} .
docker push ${BONNY_IMAGE}:latest
```

### Generating Kubernetes manifest for operator

This will generate the entire manifest for this operator including:

- CRD manifests
- RBAC
- Service Account
- Operator Deployment

The operator manifest generator requires the `image` flag to be passed if you plan to deploy the operator in your cluster. This is the docker image URL of your operators docker image created by `mix bonny.gen.docker` above.

```shell
mix bonny.gen.manifest --image ${BONNY_IMAGE}
```

You may _omit_ the `--image` flag if you want to generate a manifest _without the deployment_ so that you can develop locally running the operator outside of the cluster.

By default the manifest will generate the service account and deployment in the "default" namespace.

_To set the namespace explicitly:_

```shell
mix bonny.gen.manifest --out - -n test
```

_Alternatively you can apply it directly to kubectl_:

```shell
mix bonny.gen.manifest --out - -n test | kubectl apply -f - -n test
```
