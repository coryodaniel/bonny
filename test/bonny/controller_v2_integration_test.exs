defmodule Bonny.ControllerV2IntegrationTest do
  @moduledoc """
  The idea is for the test to create a resources with pid and ref in its spec
  and send this to kubernetes. The controller (under test) can then read those
  values from the resource it gets and send a message to the pid with the ref.
  The test asserts the message is received => QED.
  """

  use ExUnit.Case, async: true

  alias Bonny.Test.IntegrationHelper
  alias Bonny.Test.ResourceHelper

  @resource_labels %{"test" => "controller_v2"}

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
        |> K8s.Operation.put_label_selector(selector)

      {:ok, _} = K8s.Client.run(conn, delete_v2_op)
    end)

    {:ok, _} = Supervisor.start_link([{Bonny.Test.Operator, conn: conn}], strategy: :one_for_one)

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
        ResourceHelper.test_resource(resource_name, :v2, self(), ref, labels: @resource_labels),
      ref: ref
    ]
  end

  @tag :integration
  test "creating resource triggers controller", %{
    conn: conn,
    resource_name: resource_name,
    resource: resource,
    timeout: timeout,
    ref: ref
  } do
    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)

    assert_receive {^ref, :add, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout
  end

  @tag :integration
  test "updating resource triggers modify/1", %{
    conn: conn,
    resource_name: resource_name,
    resource: resource,
    timeout: timeout,
    ref: ref
  } do
    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)

    assert_receive {^ref, :add, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout

    apply_op =
      resource
      |> put_in(["spec", "rand"], "rand")
      |> K8s.Client.apply(field_manager: Bonny.Config.name())

    {:ok, _} = K8s.Client.run(conn, apply_op)

    assert_receive {^ref, :modify, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout
  end

  @tag :integration
  test "deleting resource triggers delete/1", %{
    conn: conn,
    resource_name: resource_name,
    resource: resource,
    timeout: timeout,
    ref: ref
  } do
    create_op = K8s.Client.create(resource)

    {:ok, _} = K8s.Client.run(conn, create_op)

    assert_receive {^ref, :add, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout

    delete_op = K8s.Client.delete(resource)
    {:ok, _} = K8s.Client.run(conn, delete_op)

    assert_receive {^ref, :delete, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout

    # create again so on_exit can delete it again
    {:ok, _} = K8s.Client.run(conn, create_op)
    assert_receive {^ref, :done, ^resource_name}, timeout
  end

  @tag :integration
  test "creating and updating resource sets observedGeneration", %{
    conn: conn,
    resource_name: resource_name,
    resource: resource,
    timeout: timeout,
    ref: ref
  } do
    {:ok, added_resource} = K8s.Client.run(conn, K8s.Client.create(resource))

    assert_receive {^ref, :add, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout

    get_op = K8s.Client.get(resource)

    {:ok, _} =
      K8s.Client.wait_until(conn, get_op,
        find: ["status", "observedGeneration"],
        eval: added_resource["metadata"]["generation"],
        timeout: Integer.floor_div(timeout, 1000)
      )

    # update
    apply_op =
      resource
      |> put_in(["spec", "rand"], "foo")
      |> K8s.Client.apply(field_manager: Bonny.Config.name())

    {:ok, updated_resource} = K8s.Client.run(conn, apply_op)

    assert_receive {^ref, :modify, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout

    assert updated_resource["metadata"]["generation"] > added_resource["metadata"]["generation"]

    {:ok, _} =
      K8s.Client.wait_until(conn, get_op,
        find: ["status", "observedGeneration"],
        eval: updated_resource["metadata"]["generation"],
        timeout: timeout
      )
  end

  @tag :integration
  test "creating resource creates success event", %{
    conn: conn,
    resource_name: resource_name,
    resource: resource,
    timeout: timeout,
    ref: ref
  } do
    {:ok, created_resource} = K8s.Client.run(conn, K8s.Client.create(resource))

    assert_receive {^ref, :add, ^resource_name}, timeout
    assert_receive {^ref, :done, ^resource_name}, timeout

    list_event_opt =
      K8s.Client.list("events.k8s.io/v1", "Event")
      |> K8s.Operation.put_query_param(
        :fieldSelector,
        "regarding.uid=#{created_resource["metadata"]["uid"]}"
      )

    {:ok, _} =
      K8s.Client.wait_until(conn, list_event_opt,
        find: ["items", Access.all(), "regarding", "uid"],
        eval: fn uids ->
          created_resource["metadata"]["uid"] in uids
        end,
        timeout: Integer.floor_div(timeout, 1000)
      )
  end
end
