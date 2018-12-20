defmodule Mix.Tasks.Bonny.Gen.Dockerfile do
  @moduledoc """
  Generates a Dockerfile for this operator
  """

  use Mix.Task

  @shortdoc "Generate operator Dockerfile"
  @spec run([binary()]) :: nil | :ok
  def run(_) do
    File.cp!(Mix.Bonny.template("Dockerfile"), "Dockerfile")
  end
end
