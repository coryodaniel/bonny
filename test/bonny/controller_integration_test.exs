defmodule Bonny.ControllerIntegrationTest do
  @moduledoc """
  The idea is for the test to create a resources with pid and ref in its spec
  and send this to kubernetes. The controller (under test) can then read those
  values from the resource it gets and send a message to the pid with the ref.
  The test asserts the message is received => QED.
  """

  use ExUnit.Case, async: true

  alias Bonny.Test.IntegrationHelper
  alias Bonny.Test.ResourceHelper

  setup_all do
    start_supervised!(TestResource)
    # give the watcher time to initialize:
    :timer.sleep(500)

    conn = IntegrationHelper.conn()

    on_exit(fn ->
      delete_op = K8s.Client.delete_all("example.com/v1", "TestResource", namespace: "default")
      {:ok, _} = K8s.Client.run(conn, delete_op)
    end)

    [conn: conn]
  end

  setup do
    ref = make_ref()

    resource_name =
      "test-#{ref |> :erlang.ref_to_list() |> List.to_string() |> String.replace(~r(\D), "")}"

    timeout =
      "TEST_WAIT_TIMEOUT"
      |> System.get_env("2000")
      |> String.to_integer()

    [resource_name: resource_name, timeout: timeout, ref: ref]
  end

  @tag :integration
  test "creating resource triggers add/1", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource = ResourceHelper.test_resource(resource_name, :v1, self(), ref)
    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)
    assert_receive({^ref, :added, ^resource_name}, timeout)
  end

  @tag :integration
  test "updating resource triggers modify/1", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource = ResourceHelper.test_resource(resource_name, :v1, self(), ref)
    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)
    assert_receive({^ref, :added, ^resource_name}, timeout)

    apply_op =
      resource
      |> put_in(["metadata", "labels"], %{"some" => "label"})
      |> K8s.Client.apply(field_manager: "bonny")

    {:ok, _} = K8s.Client.run(conn, apply_op)
    assert_receive({^ref, :modified, ^resource_name}, timeout)
  end

  @tag :integration
  test "deleting resource triggers delete/1", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource = ResourceHelper.test_resource(resource_name, :v1, self(), ref)
    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)
    assert_receive({^ref, :added, ^resource_name}, timeout)

    delete_op = K8s.Client.delete(resource)
    {:ok, _} = K8s.Client.run(conn, delete_op)
    assert_receive({^ref, :deleted, ^resource_name}, timeout)

    # create again so on_exit can delete it again
    {:ok, _} = K8s.Client.run(conn, create_op)
  end
end
