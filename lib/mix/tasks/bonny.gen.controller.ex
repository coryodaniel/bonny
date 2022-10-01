defmodule Mix.Tasks.Bonny.Gen.Controller do
  @moduledoc """
  Generates a new CRD controller

  An operator can have multiple controllers. Each controller handles the lifecycle of a custom resource.

  ```shell
  mix bonny.gen.controller
  ```
  Open up your controller and add functionality for your resources lifecycle:

  * Add
  * Modify
  * Delete
  * Reconcile

  If you selected to add a CRD, also edit the generated CRD version module.
  """

  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  use Mix.Task

  alias Bonny.API.ResourceEndpoint

  @switches [out: :string, help: :boolean]
  @aliases [o: :out, h: :help]

  @shortdoc "Generate a new CRD Controller for this operator"
  @spec run([binary()]) :: nil | :ok
  def run(args) do
    Mix.Bonny.no_umbrella!()

    {opts, args, _} = Mix.Bonny.parse_args(args, [], switches: @switches, aliases: @aliases)

    if opts[:help] do
      print_usage()
      exit(:normal)
    end

    binding =
      args
      |> init_values()
      |> get_input()
      |> Keyword.put(:app_name, Mix.Bonny.app_name())

    if binding[:with_crd] do
      for version <- Bonny.Config.versions() do
        binding = Keyword.put(binding, :crd_version, version)

        version_out =
          opts[:out] || crd_version_path(version, Macro.underscore(binding[:crd_name]))

        "version.ex"
        |> Mix.Bonny.template()
        |> EEx.eval_file(binding)
        |> Mix.Bonny.render(version_out)
      end
    end

    controller_filename = Macro.underscore(binding[:controller_name])
    controller_out = opts[:out] || controller_path(controller_filename)
    test_out = opts[:out] || controller_test_path(controller_filename)

    "controller.ex"
    |> Mix.Bonny.template()
    |> EEx.eval_file(binding)
    |> Mix.Bonny.render(controller_out)

    "controller_test.ex"
    |> Mix.Bonny.template()
    |> EEx.eval_file(binding)
    |> Mix.Bonny.render(test_out)
  end

  # coveralls-ignore-start trivial code and we use stdout in tests
  defp controller_path(filename) do
    Path.join(["lib", Mix.Bonny.app_dir_name(), "controllers", "#{filename}.ex"])
  end

  defp crd_version_path(version, file_name) do
    directory = version |> Module.split() |> Enum.map(&Macro.underscore/1)

    ["lib" | directory]
    |> Path.join()
    |> Path.join("#{file_name}.ex")
  end

  defp controller_test_path(filename) do
    Path.join([
      "test",
      Mix.Bonny.app_dir_name(),
      "controllers",
      "#{filename}_test.exs"
    ])
  end

  # coveralls-ignore-stop

  defp controller_name_valid?(controller_name) do
    controller_name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  def get_input(input \\ []) do
    cond do
      is_nil(input[:controller_name]) ->
        controller_name =
          Owl.IO.input(
            label:
              "What's the name of your controller? This has to be a valid Elixir module name. e.g. CronTabController"
          )

        input
        |> Keyword.put(:controller_name, controller_name)
        |> get_input()

      !controller_name_valid?(input[:controller_name]) ->
        Mix.Bonny.error(
          "The controller name you defined (#{input[:controller_name]}) is not a valid Elixir module name!"
        )

        input
        |> Keyword.delete(:controller_name)
        |> get_input()

      is_nil(input[:with_crd]) ->
        with_crd =
          Owl.IO.confirm(
            message:
              "Do you want to create a CRD with this controller? (For operators you typically do)",
            default: true
          )

        input
        |> Keyword.put(:with_crd, with_crd)
        |> get_input()

      input[:with_crd] and is_nil(input[:crd_name]) ->
        from_controller = String.replace_suffix(input[:controller_name], "Controller", "")

        crd_name =
          Owl.IO.input(
            label:
              "What's the name (kind) of the Custom Resource? (defaults to #{inspect(from_controller)})",
            optional: true
          )

        input
        |> Keyword.put(:crd_name, crd_name || from_controller)
        |> get_input()

      input[:with_crd] and !controller_name_valid?(input[:crd_name]) ->
        Mix.Bonny.error(
          "The CRD name you defined (#{input[:crd_name]}) is not a valid kubernetes kind!"
        )

        input
        |> Keyword.delete(:crd_name)
        |> get_input()

      !input[:with_crd] and is_nil(input[:resource_endpoint]) ->
        resource_endpoint =
          Owl.IO.select(
            ["ConfigMap", "Deployment", "Job", "Pod", "Secret", "Service", "other"],
            label: "What resource should your controller act on?"
          )
          |> get_resource_endpoint()

        input
        |> Keyword.put(:resource_endpoint, resource_endpoint)
        |> get_input()

      input[:resource_endpoint] == :other ->
        group =
          Owl.IO.input(
            label:
              "Enter the API group of the resource your controller should act on (e.g. \"apps\")"
          )

        version =
          Owl.IO.input(
            label:
              "Enter the API version of the resource your controller should act on (e.g. \"v1\")"
          )

        resource_type =
          Owl.IO.input(
            label:
              "Enter the plural lowercase name of the resource your controller should act on (e.g. \"deployments\")"
          )

        scope =
          Owl.IO.select(["Namespaced", "Cluster"],
            label: "What's the scope of the resource your controller should act on?"
          )
          |> String.to_atom()

        input
        |> Keyword.put(
          :resource_endpoint,
          Bonny.API.ResourceEndpoint.new!(
            group: group,
            version: version,
            resource_type: resource_type,
            scope: scope
          )
        )
        |> get_input()

      true ->
        input
    end
  end

  defp init_values(args) do
    init_values =
      args
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {arg, 0} -> [{:controller_name, arg}]
      end)

    Keyword.merge([resource_endpoint: nil, crd_name: nil], init_values)
  end

  # coveralls-ignore-start trivial code
  defp get_resource_endpoint("Secret"), do: ResourceEndpoint.new!("v1", "secrets")
  defp get_resource_endpoint("Service"), do: ResourceEndpoint.new!("v1", "services")
  defp get_resource_endpoint("ConfigMap"), do: ResourceEndpoint.new!("v1", "pods")
  defp get_resource_endpoint("Job"), do: ResourceEndpoint.new!("batch/v1", "jobs")
  defp get_resource_endpoint("Pod"), do: ResourceEndpoint.new!("v1", "configmaps")
  defp get_resource_endpoint("Deployment"), do: ResourceEndpoint.new!("apps/v1", "deployments")
  defp get_resource_endpoint("other"), do: :other
  # coveralls-ignore-stop

  defp print_usage() do
    IO.puts("""
    usage: mix bonny.gen.controller [options] [controller_name]

        controller_name:  The module name of your controller - Should be a valid Elixir module name

        options:
        -h, --help      Print this message
        -o, --out       "-" prints to stdout
    """)
  end
end
