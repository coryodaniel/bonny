defmodule Mix.Tasks.Bonny.Gen.ControllerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.Bonny.Gen.Controller
  import ExUnit.CaptureIO

  describe "run/1" do
    test "generates a new Controller module" do
      output =
        capture_io(fn ->
          Controller.run(["Memcached", "--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.Memcached do"
    end

    test "the generated controller injects the singular Controller name as the argument" do
      output =
        capture_io(fn ->
          Controller.run(["Memcached", "--out", "-"])
        end)

      assert output =~ "def apply(%{} = resource) do"
      assert output =~ "def delete(%{} = resource) do"
    end

    test "generates a test file" do
      output =
        capture_io(fn ->
          Controller.run(["Memcached", "memcached", "--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.MemcachedTest do"
    end

    test "requires a module name" do
      assert_raise Mix.Error,
                   ~r/Expected the controller "webhook" to be a valid module name/,
                   fn ->
                     capture_io(fn ->
                       Controller.run(["webhook"])
                     end)
                   end
    end
  end
end
