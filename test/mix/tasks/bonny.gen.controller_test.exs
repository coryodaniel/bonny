defmodule Mix.Tasks.Bonny.Gen.ControllerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.Bonny.Gen.Controller
  import ExUnit.CaptureIO

  defp input_args(args), do: Enum.join(args, "\n")

  setup_all do
    [
      crd_no_args: ~w(McController) |> input_args(),
      crd_arg_controller: ~w() |> input_args()
    ]
  end

  describe "run/1" do
    test "generates a CRD controller when no args are passed.",
         %{crd_no_args: input} do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-"])
        end)

      assert output =~ "defmodule Bonny.Controller.McController do"
      assert output =~ "defmodule Bonny.Controller.McControllerTest do"
    end

    test "Asks for controller name again if it is invalid.",
         %{crd_no_args: input} do
      output =
        capture_io([input: "Invalid_Controller_Name\n" <> input], fn ->
          Controller.run(["--out", "-"])
        end)

      assert output =~ "not a valid Elixir module name!"
    end

    test "generates a CRD controller when controller name is passed.",
         %{
           crd_arg_controller: input
         } do
      output =
        capture_io([input: input], fn ->
          Controller.run(["--out", "-", "McController"])
        end)

      assert output =~ "defmodule Bonny.Controller.McController do"
      assert output =~ "defmodule Bonny.Controller.McControllerTest do"
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
