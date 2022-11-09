# Migrations

## Migrating from 0.5 to a newer version

In this version of, Bonny comes with slightly a new concept. In this version you have to define an operator and add it to your application's supervision tree. Also, the processing of events are done in a Plug-like pipeline leveraging the [`Pluggable`](https://hex.pm/packages/pluggable) library. This makes controllers easeir to test but also easier to customize. See for yourself.

### Option 1: Use `mix bonny.init` on a fresh project

The probably easiest way is to start with a plain Elixir project and set up your
operator using `mix bonny.init`. Since you already know what resources and
controllers you need, this will initiate your operator, CRDs, versions and
controllers for you.
You just have to copy your controller implementation over to the generated
controllers and bring it into a `Pluggable` form.

### Option 2: Manual migration

#### Step 1: Create your Opeator

Create a new module (e.g. `YourProject.Operator`) which uses `use Bonny.Operator`,
implement `crds/0` and `controllers/2` according to the [Operator Guide](./the_operator.livemd)
and add it to your supervision tree.

#### Step 2: Create your API versions

For each custom resource your operator defines and each version the resource
supports, create the corresponding module:

```elixir
# lib/your_operator/api/v1/cron_tab.ex
defmodule YourOperator.API.V1.CronTab do
  use Bonny.API.Version

  @impl Bonny.API.Version
  def manifest(), do: struct!(defaults(), storage: true)
end
```

```elixir
# lib/your_operator/api/v1alpha1/cron_tab.ex
defmodule YourOperator.API.V1Alpha1.CronTab do
  use Bonny.API.Version

  @impl Bonny.API.Version
  def manifest(), do: defaults()
end
```

**Note that one and only one version of the same custom resource has to be flagged with `storage: true`.**

#### Step 3: Additional Printer Columns

Additional printer columns belong to CRD API versions, not to controllers. Therefore, if your
controller defined additional printer columns, move those over to the version you just created.
Modify `manifest/0` for this purpose.

```elixir
# lib/your_operator/api/v1/cron_tab.ex
defmodule YourOperator.API.V1Alpha1.CronTab do
  use Bonny.API.Version

  @impl Bonny.API.Version
  def manifest() do
    struct!(
      defaults(),
      additionalPrinterColumns: [
        %{name: "foos", type: :integer, description: "Number of foos", jsonPath: ".spec.foos"}
      ]
    )
  end
end
```

#### Step 4: Update your Controllers

Also see the [Controllers Guide](./controllers.livemd)

- Change `use Bonny.Controller` to `use Bonny.ControllerV2`
- If you have defined additional RBAC rules via `@rule {apiGroup, resources_list, verbs_list}`, implement the `rbac_rules/0`.
- If you have defined custom names via `@names %{...}`, the resource scope (e.g. `@scope :cluster`) or an API group (e.g. `@group "example.com"`),
  add these values to the CRD in your Operator (see above)
- Bring your controller to a `Pluggable` form. See the [Controllers Guide](./controllers.livemd)

After having migrated all controllers, re-generate your manifest using `mix bonny.gen.manifest`.

## Migrating from 0.4 to 0.5

Version 0.5 comes with some major changes. Please read through this migration guide before upgrading.

### Elixir Version

With version 0.5, bonny moved Elixir support from \~> 1.9 to \~> 1.10.

### Config

The dependency on `:k8s` was upgraded from `~> 0.4.0` to `~> 1.1`. With version `1.0`,
`:k8s` brought some major changes. Mainly the way the connection to the cluster
is configured. While pre `1.0`, connections were configured in `config.exs`, in `1.0`
upwards, they had to created and passed to the client by the caller. This change
affects `:bonny`, too.

Starting with version `0.5`, you no longer have to configure `:k8s`. This means
you can remove this block completely as it has no effect:

```elixir
config :k8s,
 clusters: ...
```

With `0.5`, `:bonny` however has to be configured with a new option `:get_conn`. The value of
this configuration option is supposed to be an MFA tuple that tells bonny how to get
the connection struct. The function is called by bonny and is expected to return
either `{:ok, K8s.Conn.t()}` or a `K8s.Conn.t()` directly.

```elixir
config :bonny,
  get_conn: {MyModule, :get_the_connection},
```

You can use helpers defined in `:k8s` to get the connection:

```elixir
config :bonny,
  get_conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "optional-alternate-context"]]},
```

or, when configuring bonny to run in your cluster:

```elixir
config :bonny,
  get_conn: {K8s.Conn, :from_service_account, []}
```
