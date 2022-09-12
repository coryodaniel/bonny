# Migrations

## Migrating from `Bonny.Controller` to `Bonny.ControllerV2`

If you follow these steps, you should be able to successfully migrate your controllers to V2.
The new concepts like `customize_crd/1` and RBAC rule definition are explained in the [controllers guide livebook](./controllers.livemd).

- Change `use Bonny.Controller` to `use Bonny.ControllerV2`
- If you have defined additional RBAC rules via `@rule {apiGroup, resources_list, verbs_list}`, add an option `rbac_rule: {apiGroup, resources_list, verbs_list}` to the `use` statement **for each `@rule` attribute**.
- If you have defined a custom version, e.g. `@version "v2alpha1"`, implement `customize_crd/1` and change the default version name.
- If you have defined a custom group, e.g. `@group kewl.example.com`, implement `customize_crd/1` and change the group in your CRD.
- If you have defined your controller to operate on cluster scope (i.e. `@scope :cluster`), implement `customize_crd/1` and change the scope in your CRD.
- If you have defined custom names via `@names %{...}`, implement `customize_crd/1` and change the names in your CRD.
- If you have defined additional printer columns, implement `customize_crd/1` and add them to the auto-generated default version in your CRD. There's a section in the [controllers guide livebook](./controllers.livemd) about this.

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
