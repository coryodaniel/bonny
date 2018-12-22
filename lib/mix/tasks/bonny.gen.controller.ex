defmodule Mix.Tasks.Bonny.Gen.Controller do
  @moduledoc """
  Generates a new CRD controller

  An operator can have multiple controllers. Each controller handles the lifecycle of a custom resource.

  By default controllers are generated in the `V1` version scope.

  ```shell
  mix bonny.gen.controller Widget widget
  ```

  You can specify the version flag to create a new version of a controller. Bonny will dispatch the controller for the given version. So old versions of resources can live alongside new versions.

  ```shell
  mix bonny.gen.controller Widget widget --version v2alpha1
  ```

  *Note:* The one restriction with versions is that they will be camelized into a module name.

  Open up your controller and add functionality for your resoures lifecycle:

  * Add
  * Modify
  * Delete

  Each controller can create multiple resources.

  For example, a *todo app* controller could deploy a `Deployment` and a `Service`.
  """

  use Mix.Task

  @switches [version: :string, out: :string]
  @default_opts [version: "v1"]
  @aliases [o: :out, v: :version]

  @shortdoc "Generate a new CRD Controller for this operator"
  @spec run([binary()]) :: nil | :ok
  def run(args) do
    Mix.Bonny.no_umbrella!()

    {mod_name, singular, plural, version, opts} = build(args)

    binding = [
      mod_name: mod_name,
      singular: singular,
      version: version,
      plural: plural,
      app_name: Mix.Bonny.app_name()
    ]

    controller_out = opts[:out] || controller_path(opts[:version], singular)
    test_out = opts[:out] || test_path(opts[:version], singular)

    "controller.ex"
    |> Mix.Bonny.template()
    |> EEx.eval_file(binding)
    |> Mix.Bonny.render(controller_out)

    "controller_test.ex"
    |> Mix.Bonny.template()
    |> EEx.eval_file(binding)
    |> Mix.Bonny.render(test_out)
  end

  defp controller_path(version, singular) do
    Path.join(["lib", Mix.Bonny.app_dir_name(), "controllers", version, "#{singular}.ex"])
  end

  defp test_path(version, singular) do
    Path.join(["test", Mix.Bonny.app_dir_name(), "controllers", version, "#{singular}_test.exs"])
  end

  defp build(args) do
    {opts, parsed, _} =
      Mix.Bonny.parse_args(args, @default_opts, switches: @switches, aliases: @aliases)

    [mod_name, plural | _] = validate_args!(parsed)

    version = Macro.camelize(opts[:version])
    singular = Macro.underscore(mod_name)

    {mod_name, singular, plural, version, opts}
  end

  defp validate_args!(args = [mod_name, _plural | _]) do
    if mod_name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      args
    else
      raise_with_help("Expected the controller #{inspect(mod_name)} to be a valid module name")
    end
  end

  defp validate_args!([_mod_name]) do
    raise_with_help("Expected a controller module name followed by the plural form")
  end

  defp validate_args!(_) do
    raise_with_help("Invalid arguments.")
  end

  @doc false
  @spec raise_with_help(String.t()) :: no_return()
  def raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    mix bonny.gen.controller expects a module name followed by a the plural
    name of the generated resource.

    For example:
       mix bonny.gen.controller Webhook webhooks
       mix bonny.gen.controller Memcached memcached
       mix bonny.gen.controller Memcached memcached --version v1alpha1
    """)
  end
end
