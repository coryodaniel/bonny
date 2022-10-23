defmodule Mix.Tasks.Bonny.Gen.ControllerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.Bonny.Gen.Controller
  import ExUnit.CaptureIO

  defp input_args(args), do: Enum.join(args, "\n")

  @choice_resource_deployment "2"
  @choice_resource_other "72"

  @choice_scope_namespaced "1"

  setup_all do
    [
      crd_no_args: ~w(McController y Memcached) |> input_args(),
      crd_arg_controller: ~w(y Memcached) |> input_args(),
      crd_arg_controller_inv: ~w(y Mem_Cached Memcached) |> input_args(),
      crd_arg_controller_version: ~w(y Memcached) |> input_args(),
      deployment_no_args: ["DeplController", "n", @choice_resource_deployment] |> input_args(),
      deployment_arg_controller: ["n", @choice_resource_deployment] |> input_args(),
      sealed_secret_no_args:
        [
          "SealedSecretController",
          "n",
          @choice_resource_other,
          "bitnami.com",
          "sealedsecrets",
          @choice_scope_namespaced
        ]
        |> input_args(),
      sealed_secret_arg_controller:
        [
          "n",
          @choice_resource_other,
          "bitnami.com",
          "sealedsecrets",
          @choice_scope_namespaced
        ]
        |> input_args()
    ]
  end

  describe "run/1" do
    test "generates a CRD controller and a Version module when no args are passed.",
         %{crd_no_args: input} do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.McController do"
      assert output =~ "defmodule Bonny.Controller.McControllerTest do"
      assert output =~ "defmodule Bonny.Test.API.V1.Memcached do"
    end

    test "Asks for controller name again if it is invalid.",
         %{crd_no_args: input} do
      output =
        capture_io([input: "Invalid_Controller_Name\n" <> input], fn ->
          Controller.run(["--out", "-"])
        end)

      assert output =~ "not a valid Elixir module name!"
    end

    test "Asks for CRD name again if it is invalid.",
         %{crd_arg_controller_inv: input} do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-", "McController"])
        end)

      assert output =~ "is not a valid kubernetes kind!"
    end

    test "generates a CRD controller and a Version module module when controller name is passed.",
         %{
           crd_arg_controller: input
         } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-", "McController"])
        end)

      assert output =~ "defmodule Bonny.Controller.McController do"
      assert output =~ "defmodule Bonny.Controller.McControllerTest do"
      assert output =~ "defmodule Bonny.Test.API.V1.Memcached do"
    end

    test "generates a CRD controller and a Version module module when controller name and version are passed.",
         %{
           crd_arg_controller_version: input
         } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-", "McController"])
        end)

      assert output =~ "defmodule Bonny.Controller.McController do"
      assert output =~ "defmodule Bonny.Test.API.V1.Memcached do"
    end

    test "generates a deployment controller when no args are passed.",
         %{
           deployment_no_args: input
         } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.DeplController do"
      assert output =~ "defmodule Bonny.Controller.DeplControllerTest do"
    end

    test "generates a deployment controller when controller name is passed.",
         %{
           deployment_arg_controller: input
         } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-", "DeplController"])
        end)

      assert output =~ "defmodule Bonny.Controller.DeplController do"
      assert output =~ "defmodule Bonny.Controller.DeplControllerTest do"
    end

    test "generates a sealed secret controller when no args are passed.",
         %{
           sealed_secret_no_args: input
         } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.SealedSecretController do"
      assert output =~ "defmodule Bonny.Controller.SealedSecretController do"
    end

    test "generates a sealed secret controller when controller name is passed.",
         %{
           sealed_secret_arg_controller: input
         } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-", "SealedSecretController"])
        end)

      assert output =~ "defmodule Bonny.Controller.SealedSecretController do"
      assert output =~ "defmodule Bonny.Controller.SealedSecretControllerTest do"
    end

    test "generated modules compile (with crd)", %{crd_no_args: input} do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      _modules =
        output
        |> String.replace(~r/^.*?defmodule/s, "defmodule")
        |> String.replace(
          ~r/.*Don't forget to add the controller to the list of controllers in your application config.*/,
          ""
        )
        |> Code.compile_string()
    end

    test "generated modules compile (deployment)", %{deployment_no_args: input} do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      _modules =
        output
        |> String.replace(~r/^.*?defmodule/s, "defmodule")
        |> String.replace(
          ~r/.*Don't forget to add the controller to the list of controllers in your application config.*/,
          ""
        )
        |> Code.compile_string()
    end

    test "generated modules compile (sealed secret)", %{sealed_secret_no_args: input} do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      _modules =
        output
        |> String.replace(~r/^.*?defmodule/s, "defmodule")
        |> String.replace(
          ~r/.*Don't forget to add the controller to the list of controllers in your application config.*/,
          ""
        )
        |> Code.compile_string()
    end

    test "the generated controller injects the singular Controller name as the argument", %{
      crd_no_args: input
    } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      assert output =~ "step :handle_event"
      assert output =~ "def handle_event("
    end

    test "generates a test file", %{
      crd_no_args: input
    } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.McControllerTest do"
    end

    test "prints the help message" do
      output =
        capture_io(fn ->
          catch_exit(Controller.run(["-h"]))
        end)

      assert output =~ "mix bonny.gen.controller"
    end
  end
end
