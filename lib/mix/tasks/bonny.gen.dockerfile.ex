defmodule Mix.Tasks.Bonny.Gen.Dockerfile do
  @moduledoc """
  Generates a Dockerfile for this operator
  """

  use Mix.Task

  @switches [out: :string, elixir_image_tag: :string, otp_image_tag: :string]
  @default_opts [out: "Dockerfile", elixir_image_tag: "1.14", otp_image_tag: "25.1"]
  @aliases [o: :out, ex: :elixir_image_tag, otp: :otp_image_tag]

  @shortdoc "Generate operator Dockerfile"
  @spec run([binary()]) :: nil | :ok
  def run(args) do
    {opts, _, _} =
      Mix.Bonny.parse_args(args, @default_opts, switches: @switches, aliases: @aliases)

    binding = [
      app_name: Mix.Bonny.app_dir_name(),
      elixir_image_tag: opts[:elixir_image_tag],
      otp_image_tag: opts[:otp_image_tag]
    ]

    "Dockerfile"
    |> Mix.Bonny.template()
    |> EEx.eval_file(binding)
    |> Mix.Bonny.render(opts[:out])
  end
end
