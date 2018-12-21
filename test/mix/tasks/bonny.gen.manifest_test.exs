defmodule Mix.Tasks.Bonny.Gen.ManifestTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.Bonny.Gen.Manifest
  import ExUnit.CaptureIO

  describe "run/1" do
    test "manifest includes CRDs" do
      output =
        capture_io(fn ->
          Manifest.run(["--out", "-"])
        end)

      assert output =~ "CustomResourceDefinition"
    end

    test "manifest includes RBAC" do
      output =
        capture_io(fn ->
          Manifest.run(["--out", "-"])
        end)

      assert output =~ "ServiceAccount"
      assert output =~ "ClusterRoleBinding"
      assert output =~ "ClusterRole"
    end

    # test "manifest includes Deployment"
  end
end
