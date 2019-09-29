defmodule Mix.Tasks.Bonny.Gen.DockerfileTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.Bonny.Gen.Dockerfile
  import ExUnit.CaptureIO

  describe "run/1" do
    test "generates a Dockerfile using the application name" do
      output =
        capture_io(fn ->
          Dockerfile.run(["--out", "-"])
        end)

      assert output =~ "/app/_build/prod/rel/bonny"
    end
  end
end
