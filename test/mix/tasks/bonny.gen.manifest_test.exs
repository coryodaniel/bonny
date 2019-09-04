defmodule Mix.Tasks.Bonny.Gen.ManifestTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.Bonny.Gen.Manifest
  import ExUnit.CaptureIO

  describe "run/1" do
    test "manifest includes CRDs" do
      output =
        capture_io(fn ->
          Manifest.run(["-i", "quay.io/foo/bar", "--out", "-"])
        end)

      assert output =~ "CustomResourceDefinition"
    end

    test "manifest includes additional printer columns" do
      output =
        capture_io(fn ->
          Manifest.run(["-i", "quay.io/foo/bar", "--out", "-"])
        end)

      assert output =~ "additionalPrinterColumns"
    end

    test "manifest includes RBAC" do
      output =
        capture_io(fn ->
          Manifest.run(["-i", "quay.io/foo/bar", "--out", "-"])
        end)

      IO.puts(output)
      assert output =~ "ServiceAccount"
      assert output =~ "ClusterRoleBinding"
      assert output =~ "ClusterRole"
      assert output =~ "rules"
    end

    test "manifest excludes Deployment when not specifying an image" do
      output =
        capture_io(fn ->
          Manifest.run(["--out", "-"])
        end)

      refute output =~ "Deployment"
    end

    test "manifest includes Deployment when specifying an image" do
      output =
        capture_io(fn ->
          Manifest.run(["-i", "quay.io/foo/bar", "--out", "-"])
        end)

      assert output =~ "Deployment"
      assert output =~ "quay.io/foo/bar"
    end
  end
end
