defmodule Bonny.AxnIntegrationTest do
  use ExUnit.Case, async: true
  use Bonny.Axn.Test

  import ExUnit.CaptureLog

  alias Bonny.Axn, as: MUT
  alias Bonny.Test.IntegrationHelper
  alias Bonny.Test.ResourceHelper

  @resource_label %{"test" => "axn"}

  setup_all do
    conn = IntegrationHelper.conn()
    start_supervised!({Bonny.EventRecorder, operator: __MODULE__})

    on_exit(fn ->
      selector = K8s.Selector.label(@resource_label)

      delete_v2_op =
        K8s.Client.delete_all("example.com/v1", "TestResourceV3", namespace: "default")
        |> K8s.Operation.put_label_selector(selector)

      {:ok, _} = K8s.Client.run(conn, delete_v2_op)
    end)

    [
      conn: conn
    ]
  end

  setup do
    ref = make_ref()
    resource_name = "test-#{ref |> ResourceHelper.to_string() |> String.replace(~r(\D), "")}"

    [
      resource:
        ResourceHelper.test_resource(resource_name, :v3, self(), ref, labels: @resource_label)
    ]
  end

  describe "apply_status/2" do
    @tag :integration
    test "runs without errors", %{conn: conn, resource: resource} do
      {:ok, added_resource} = K8s.Client.run(conn, K8s.Client.apply(resource))

      log =
        capture_log(fn ->
          axn(:add, conn: conn, resource: added_resource)
          |> MUT.update_status(fn _ -> %{"foo" => "bar"} end)
          |> MUT.apply_status()
        end)

      refute log =~ "Failed applying resource status."
    end

    @tag :integration
    test "logs errors returned by k8s", %{conn: conn, resource: resource} do
      {:ok, added_resource} = K8s.Client.run(conn, K8s.Client.apply(resource))

      log =
        capture_log(fn ->
          assert_raise RuntimeError, ~r/Failed applying resource status./, fn ->
            axn(:add, conn: conn, resource: added_resource)
            |> MUT.update_status(fn _ -> %{"foo" => 1} end)
            |> MUT.apply_status()
          end
        end)

      assert log =~ ".status.foo: expected string, got"
    end
  end

  describe "apply_descendants/2" do
    @tag :integration
    test "runs without errors", %{conn: conn, resource: resource} do
      {:ok, added_resource} = K8s.Client.run(conn, K8s.Client.apply(resource))

      log =
        capture_log(fn ->
          axn(:add, conn: conn, resource: added_resource)
          |> MUT.register_descendant(
            ResourceHelper.test_resource("test-descendant", :v2, self(), make_ref(),
              labels: @resource_label
            )
          )
          |> MUT.apply_descendants()
        end)

      refute log =~ "Failed applying descending (child) resource"
    end

    @tag :integration
    test "logs errors returned by k8s", %{conn: conn, resource: resource} do
      {:ok, added_resource} = K8s.Client.run(conn, K8s.Client.apply(resource))

      log =
        capture_log(fn ->
          assert_raise RuntimeError, ~r/uid mismatch/, fn ->
            axn(:add, conn: conn, resource: added_resource)
            |> MUT.register_descendant(ResourceHelper.widget())
            |> MUT.apply_descendants()
          end
        end)

      assert log =~ "uid mismatch"
    end
  end

  describe "emit_events/1" do
    @tag :integration
    test "runs without errors", %{conn: conn, resource: resource} do
      log =
        capture_log(fn ->
          axn(:add, conn: conn, resource: resource, operator: __MODULE__)
          |> MUT.success_event()
          |> MUT.emit_events()
        end)

      refute log =~ "Failed emitting event."
    end

    @tag :integration
    test "logs errors returned by k8s", %{conn: conn, resource: resource} do
      log =
        capture_log(fn ->
          axn(:add, conn: conn, resource: resource, operator: __MODULE__)
          |> MUT.register_event(:InvalidType, "some reason", :add, "some message")
          |> MUT.emit_events()
        end)

      assert log =~ ~s|type: Invalid value: "": has invalid value: InvalidType|
    end
  end
end
