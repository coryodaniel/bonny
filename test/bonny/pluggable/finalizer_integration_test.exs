defmodule Bonny.Pluggable.FinalizerIntegrationTest do
  use ExUnit.Case, async: false

  alias Bonny.Test.IntegrationHelper
  alias Bonny.Test.ResourceHelper

  @resource_labels %{"test" => "finalizer-step"}

  setup_all do
    timeout =
      "TEST_WAIT_TIMEOUT"
      |> System.get_env("5000")
      |> String.to_integer()

    conn = IntegrationHelper.conn()

    on_exit(fn ->
      selector = K8s.Selector.label(@resource_labels)

      delete_v2_op =
        K8s.Client.delete_all("example.com/v1", "TestResourceV2", namespace: "default")
        |> K8s.Operation.put_selector(selector)

      {:ok, _} = K8s.Client.run(conn, delete_v2_op)
    end)

    if is_nil(Process.whereis(Bonny.Test.Operator)) do
      {:ok, _} =
        Supervisor.start_link([{Bonny.Test.Operator, name: Bonny.Test.Operator, conn: conn}],
          strategy: :one_for_one
        )
    end

    # Give watch process some time to start.
    Process.sleep(600)

    [timeout: timeout]
  end

  setup do
    ref = make_ref()

    resource_name = "test-#{ref |> ResourceHelper.to_string() |> String.replace(~r(\D), "")}"

    conn = IntegrationHelper.conn()

    [
      conn: conn,
      resource_name: resource_name,
      resource:
        ResourceHelper.test_resource(resource_name, :v2, self(), ref,
          labels: @resource_labels,
          annotations: %{"add-finalizers" => "True"}
        ),
      ref: ref
    ]
  end

  @tag :integration
  test "adds finalizers to resource and calls implementation", %{
    conn: conn,
    resource_name: resource_name,
    resource: resource,
    timeout: timeout,
    ref: ref
  } do
    {:ok, added_resource} =
      resource
      |> K8s.Client.create()
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()

    assert_receive {^ref, :add, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout

    {:ok, resource} =
      added_resource
      |> K8s.Client.get()
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.wait_until(
        find: ["status", "observedGeneration"],
        eval: added_resource["metadata"]["generation"],
        timeout: Integer.floor_div(timeout, 1000)
      )

    finalizers = resource["metadata"]["finalizers"]
    assert [_ | _] = finalizers
    assert "example.com/cleanup" in finalizers
    assert "example.com/cleanup2" in finalizers

    resource
    |> K8s.Client.delete()
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()

    assert_receive {^ref, :cleanup, ^resource_name}, timeout
    assert_receive {^ref, :cleanup2, ^resource_name}, timeout
    assert_receive {^ref, :delete, ^resource_name}, timeout
  end

  @tag :integration
  test "removes finalizers from resource and does call implementation if annotation missing", %{
    conn: conn,
    resource_name: resource_name,
    resource: resource,
    timeout: timeout,
    ref: ref
  } do
    resource = put_in(resource["metadata"]["annotations"], %{})

    {:ok, added_resource} =
      resource
      |> K8s.Client.create()
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()

    assert_receive {^ref, :add, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout

    {:ok, resource} =
      added_resource
      |> K8s.Client.get()
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.wait_until(
        find: ["status", "observedGeneration"],
        eval: added_resource["metadata"]["generation"],
        timeout: Integer.floor_div(timeout, 1000)
      )

    finalizers = resource["metadata"]["finalizers"]
    assert is_nil(finalizers) or finalizers == []

    resource
    |> K8s.Client.delete()
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()

    refute_receive {^ref, :cleanup, ^resource_name}
    refute_receive {^ref, :cleanup2, ^resource_name}
    assert_receive {^ref, :delete, ^resource_name}, timeout
  end
end
