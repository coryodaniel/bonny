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

    Owl.IO.puts([
      Owl.Data.tag(
        "Don't forget to add the controller to controllers/2 in your operator.",
        :yellow
      )
    ])

    binding
  end

  # coveralls-ignore-start trivial code and we use stdout in tests
  defp controller_path(filename) do
    Path.join(["lib", Mix.Bonny.app_dir_name(), "controllers", "#{filename}.ex"])
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
    controller_name =~ ~r/^[A-Z][^\W_]*(\.[A-Z]\[^\W_]*)*$/
  end

  def get_input(input) do
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

      true ->
        input
    end
  end

  defp init_values(args) do
    args
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {arg, 0} -> [{:controller_name, arg}]
    end)
  end

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
