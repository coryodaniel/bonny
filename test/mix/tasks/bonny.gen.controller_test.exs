defmodule Mix.Tasks.Bonny.Gen.ControllerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.Bonny.Gen.Controller
  import ExUnit.CaptureIO

  describe "run/1" do
    test "generates a new Controller module" do
      output =
        capture_io(fn ->
          Controller.run(["Memcached", "memcached", "--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.V1.Memcached do"
    end

    test "the generated controller injects the singular Controller name as the argument" do
      output =
        capture_io(fn ->
          Controller.run(["Memcached", "memcached", "--out", "-"])
        end)

      assert output =~ "def add(%{} = memcached) do"
      assert output =~ "def modify(%{} = memcached) do"
      assert output =~ "def delete(%{} = memcached) do"
      assert output =~ "def reconcile(%{} = memcached) do"
    end

    test "generates a test file" do
      output =
        capture_io(fn ->
          Controller.run(["Memcached", "memcached", "--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.V1.MemcachedTest do"
    end

    test "accepts a version flag" do
      output =
        capture_io(fn ->
          Controller.run(["Memcached", "memcached", "--version", "v1alpha1", "--out", "-"])
        end)

      assert output =~ "V1alpha1.Memcached"
    end

    test "requires a module name" do
      assert_raise Mix.Error,
                   ~r/Expected the controller "webhook" to be a valid module name/,
                   fn ->
                     capture_io(fn ->
                       Controller.run(["webhook", "webhooks"])
                     end)
                   end
    end

    test "requires a plural name" do
      assert_raise Mix.Error,
                   ~r/Expected a controller module name followed by the plural form/,
                   fn ->
                     capture_io(fn ->
                       Controller.run(["webhook"])
                     end)
                   end
    end
  end
end
