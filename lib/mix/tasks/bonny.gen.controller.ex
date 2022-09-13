defmodule Mix.Tasks.Bonny.Gen.Controller do
  @moduledoc """
  Generates a new CRD controller

  An operator can have multiple controllers. Each controller handles the lifecycle of a custom resource.

  ```shell
  mix bonny.gen.controller Widget
  ```
  Open up your controller and add functionality for your resources lifecycle:

  * Apply
  * Delete

  Optionally implement `customize_crd/1` in your generated controller e.g. to define an OpenAPIV3Schema
  or define additional printer columns.

  Each controller can create multiple resources.

  For example, a *todo app* controller could deploy a `Deployment` and a `Service`.
  """

  use Mix.Task

  @switches [out: :string]
  @aliases [o: :out]

  @shortdoc "Generate a new CRD Controller for this operator"
  @spec run([binary()]) :: nil | :ok
  def run(args) do
    Mix.Bonny.no_umbrella!()

    {mod_name, file_name, opts} = build(args)

    binding = [
      mod_name: mod_name,
      app_name: Mix.Bonny.app_name()
    ]

    controller_out = opts[:out] || controller_path(file_name)
    test_out = opts[:out] || test_path(file_name)

    "controller.ex"
    |> Mix.Bonny.template()
    |> EEx.eval_file(binding)
    |> Mix.Bonny.render(controller_out)

    "controller_test.ex"
    |> Mix.Bonny.template()
    |> EEx.eval_file(binding)
    |> Mix.Bonny.render(test_out)
  end

  defp controller_path(file_name) do
    Path.join(["lib", Mix.Bonny.app_dir_name(), "controllers", "#{file_name}.ex"])
  end

  defp test_path(file_name) do
    Path.join(["test", Mix.Bonny.app_dir_name(), "controllers", "#{file_name}_test.exs"])
  end

  defp build(args) do
    {opts, parsed, _} = Mix.Bonny.parse_args(args, [], switches: @switches, aliases: @aliases)

    [mod_name | _] = validate_args!(parsed)

    file_name = Macro.underscore(mod_name)

    {mod_name, file_name, opts}
  end

  defp validate_args!([mod_name | _] = args) do
    if mod_name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      args
    else
      raise_with_help("Expected the controller #{inspect(mod_name)} to be a valid module name")
    end
  end

  defp validate_args!(_) do
    raise_with_help("Invalid arguments.")
  end

  @doc false
  @spec raise_with_help(String.t()) :: no_return()
  def raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    mix bonny.gen.controller expects a module name representing the resource's "Kind".

    For example:
       mix bonny.gen.controller Webhook
       mix bonny.gen.controller Memcached
    """)
  end
end
