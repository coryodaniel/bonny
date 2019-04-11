defmodule Mix.Tasks.Bonny.Gen.DockerfileTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.Bonny.Gen.Dockerfile
  import ExUnit.CaptureIO

  describe "run/1" do
    test "generates a Dockerfile" do
      output =
        capture_io(fn ->
          Dockerfile.run(["--out", "-"])
        end)

      assert output =~ "FROM elixir"
    end
  end
end
