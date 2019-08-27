defmodule Mix.Tasks.Bonny.Gen.Dockerfile do
  @moduledoc """
  Generates a Dockerfile for this operator
  """

  use Mix.Task

  @switches [out: :string]
  @default_opts []
  @aliases [o: :out]

  @shortdoc "Generate operator Dockerfile"
  @spec run([binary()]) :: nil | :ok
  def run(args) do
    {opts, _, _} =
      Mix.Bonny.parse_args(args, @default_opts, switches: @switches, aliases: @aliases)

    binding = [
      app_name: Mix.Bonny.app_dir_name()
    ]

    "Dockerfile"
    |> Mix.Bonny.template()
    |> EEx.eval_file(binding)
    |> Mix.Bonny.render(opts[:out])
  end
end
