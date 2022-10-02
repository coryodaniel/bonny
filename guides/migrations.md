# Migrations

## Migrating from 0.5 to a newer version

This version of Bonny introduces a new controller module `Bonny.ControllerV2` and deprecates the old `Bonny.Controller`
Follow these steps to migrate your operator to work with `Bonny.ControllerV2`.

### Add API Versions to Application Configuration

With this version of Bonny, API Versions are configured in the application config. This was done to bring
bonny closer to the [Concepts of the Kubernetes API](https://kubernetes.io/docs/concepts/overview/kubernetes-api/#api-groups-and-versioning).

> Versioning is done at the API level rather than at the resource or field level to ensure that the API presents a clear, consistent view of system resources and behavior, and to enable controlling access to end-of-life and/or experimental APIs.

Assuming you already configured the API Group in config.exs, now also add a list of versions. This should be a list of Elixir Modules.
**Note that these modules don't have to exist.**

```elixir
# config.exs

config :bonny,

  # ... other config ...

  # Set the Kubernetes API group for this operator.
  group: "your-operator.example.com",

  # Set the Kubernetes API versions for this operator.
  # This should be written in Elixir module form, e.g. YourOperator.API.V1 or YourOperator.API.V1Alpha1:
  versions: [YourOperator.API.V1, YourOperator.API.V1Alpha1],

  # ... other config ...
```

### Option1: Use `mix bonny.gen.controller`

You can use the refurbished `mix bonny.gen.controller` to create a new
version of your existing controller. Since with this version, controllers
are not versioned anymore, the file will not be inside a `/v1/` folder.
This means your existing controller won't be overwritten.

### Option 2: Manual migration of your controllers

#### Step 1 Create your API versions

For each version you added to your application config above, create the corresponding folder:

```bash
mkdir lib/your_operator/api/v1 lib/your_operator/api/v1alpha1
```

Next, for each CRD your operator generates, add a module inside those folders.
**Note that one and only one version of the same custom resource has to be flagged with `storage: true`.**

```elixir
# lib/your_operator/api/v1/cron_tab.ex
defmodule YourOperator.API.V1.CronTab do
  use Bonny.API.Version

  @impl Bonny.API.Version
  def manifest(), do: struct!(default(), storage: true)
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

#### Step 2: Additional Printer Columns

Additional printer columns belong to CRD API versions, not to controllers. Therefore, if your
controller defined additional printer columns, move those over to the verison you just created.
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

#### Step 3: Update your Controllers

- Change `use Bonny.Controller` to:

  ```elixir
  use Bonny.ControllerV2,
    for_resource: Bonny.API.CRD.build_for_controller!(
      names: Bonny.API.CRD.kind_to_names("CronTab"),
      # scope: :Namespaced (is the default),
      # group: "example.com" defaults to the API group in your config
    ),
  ```

- If you have defined additional RBAC rules via `@rule {apiGroup, resources_list, verbs_list}`, replace each `@rule` attribute with a call to `rbac_rule({apiGroup, resources_list, verbs_list})`.
- If you have defined custom names via `@names %{...}`, pass `names: %{singular: ...}` to `Bonny.API.CRD.build_for_controller!/1` or use the `Bonny.API.CRD.kind_to_names/1` helper.
- If you have defined your controller to operate on cluster scope (i.e. `@scope :cluster`), pass `scope: cluster` to `Bonny.API.CRD.build_for_controller!/1`.
- If you have defined a group that differs from the one from the application config, pass `group: "the-group.com"` to `Bonny.API.CRD.build_for_controller!/1`.
- If you have defined a version that differs from the one form application config, pass `versions: [YourOperator.API.V1.CronTab]` to `Bonny.API.CRD.build_for_controller!/1`. (replace `V1` with the version and `CronTab` with the resource kind)

The new concepts introduced with `Bonny.ControllerV2` are explained in the [controllers guide livebook](./controllers.livemd).

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
