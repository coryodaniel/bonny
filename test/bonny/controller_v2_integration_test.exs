defmodule Bonny.ControllerV2IntegrationTest do
  @moduledoc """
  The idea is for the test to create a resources with pid and ref in its spec
  and send this to kubernetes. The controller (under test) can then read those
  values from the resource it gets and send a message to the pid with the ref.
  The test asserts the message is received => QED.
  """

  use ExUnit.Case, async: true

  alias Bonny.Test.IntegrationHelper

  setup_all do
    Supervisor.start_link([TestResourceV2, TestResourceV3], strategy: :one_for_one)
    # give the watcher time to initialize:
    :timer.sleep(500)

    on_exit(fn ->
      conn = IntegrationHelper.conn()

      delete_v2_op =
        K8s.Client.delete_all("example.com/v1", "TestResourceV2", namespace: "default")

      delete_v3_op =
        K8s.Client.delete_all("example.com/v1", "TestResourceV3", namespace: "default")

      {:ok, _} = K8s.Client.run(conn, delete_v2_op)
      {:ok, _} = K8s.Client.run(conn, delete_v3_op)
    end)

    :ok
  end

  setup do
    ref = make_ref()

    resource_name =
      "test-#{ref |> :erlang.ref_to_list() |> List.to_string() |> String.replace(~r(\D), "")}"

    conn = IntegrationHelper.conn()

    timeout =
      "TEST_WAIT_TIMEOUT"
      |> System.get_env("2000")
      |> String.to_integer()

    [conn: conn, resource_name: resource_name, timeout: timeout, ref: ref]
  end

  @tag :integration
  test "creating resource triggers add/1", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource = IntegrationHelper.create_test_resource(resource_name, :v2, self(), ref)
    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)

    assert_receive(
      {^ref, :created, ^resource_name},
      timeout
    )
  end

  @tag :integration
  test "updating resource triggers modify/1", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource = IntegrationHelper.create_test_resource(resource_name, :v2, self(), ref)
    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)

    assert_receive(
      {^ref, :created, ^resource_name},
      timeout
    )

    apply_op =
      resource
      |> put_in(["metadata", "labels"], %{"some" => "label"})
      |> K8s.Client.apply(field_manager: Bonny.Config.name())

    {:ok, _} = K8s.Client.run(conn, apply_op)

    assert_receive(
      {^ref, :modified, ^resource_name},
      timeout
    )
  end

  @tag :integration
  test "deleting resource triggers delete/1", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource = IntegrationHelper.create_test_resource(resource_name, :v2, self(), ref)
    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)

    assert_receive(
      {^ref, :created, ^resource_name},
      timeout
    )

    delete_op = K8s.Client.delete(resource)
    {:ok, _} = K8s.Client.run(conn, delete_op)

    assert_receive(
      {^ref, :deleted, ^resource_name},
      timeout
    )

    # create again so on_exit can delete it again
    {:ok, _} = K8s.Client.run(conn, create_op)
  end

  @tag :integration
  test "reconcile/1 is called", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource =
      IntegrationHelper.create_test_resource(resource_name, :v3, self(), ref,
        labels: %{"version" => "3.2"}
      )

    create_op = K8s.Client.create(resource)
    {:ok, _} = K8s.Client.run(conn, create_op)

    start_supervised(TestResourceV32)

    assert_receive(
      {^ref, :reconciled, ^resource_name},
      timeout
    )
  end

  @tag :integration
  test "creating and updating resource sets observedGeneration", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource =
      IntegrationHelper.create_test_resource(resource_name, :v3, self(), ref,
        labels: %{"version" => "3.1"}
      )

    # create
    create_op = K8s.Client.create(resource)
    {:ok, created_resource} = K8s.Client.run(conn, create_op)

    assert_receive(
      {^ref, :created, ^resource_name},
      timeout
    )

    get_op = K8s.Client.get(resource)

    {:ok, _} =
      K8s.Client.wait_until(conn, get_op,
        find: ["status", "observedGeneration"],
        eval: created_resource["metadata"]["generation"],
        timeout: timeout
      )

    # update
    apply_op =
      resource
      |> put_in(["spec", "rand"], "foo")
      |> K8s.Client.apply(field_manager: Bonny.Config.name())

    {:ok, updated_resource} = K8s.Client.run(conn, apply_op)

    assert_receive(
      {^ref, :modified, ^resource_name},
      timeout
    )

    assert updated_resource["metadata"]["generation"] > created_resource["metadata"]["generation"]

    {:ok, _} =
      K8s.Client.wait_until(conn, get_op,
        find: ["status", "observedGeneration"],
        eval: updated_resource["metadata"]["generation"],
        timeout: timeout
      )
  end

  @tag :integration
  test "reconciling resource sets observedGeneration", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource =
      IntegrationHelper.create_test_resource(resource_name, :v3, self(), ref,
        labels: %{"version" => "3.2"}
      )

    create_op = K8s.Client.create(resource)
    {:ok, created_reource} = K8s.Client.run(conn, create_op)

    start_supervised(TestResourceV32)

    assert_receive(
      {^ref, :reconciled, ^resource_name},
      timeout
    )

    get_op = K8s.Client.get(resource)

    {:ok, _} =
      K8s.Client.wait_until(conn, get_op,
        find: ["status", "observedGeneration"],
        eval: created_reource["metadata"]["generation"],
        timeout: timeout
      )
  end

  @tag :integration
  test "action callbacks are not triggered if spec does not change", %{
    conn: conn,
    resource_name: resource_name,
    timeout: timeout,
    ref: ref
  } do
    resource =
      IntegrationHelper.create_test_resource(resource_name, :v3, self(), ref,
        labels: %{"version" => "3.1"}
      )

    create_op = K8s.Client.create(resource)
    {:ok, created_resource} = K8s.Client.run(conn, create_op)

    assert_receive(
      {^ref, :created, ^resource_name},
      timeout
    )

    get_op = K8s.Client.get(resource)

    {:ok, _} =
      K8s.Client.wait_until(conn, get_op,
        find: ["status", "observedGeneration"],
        eval: created_resource["metadata"]["generation"],
        timeout: timeout
      )

    # updating metadata does not change the generation
    apply_op =
      resource
      |> put_in(~w(metadata labels), %{"some" => "label"})
      |> K8s.Client.apply(field_manager: Bonny.Config.name())

    {:ok, updated_resource} = K8s.Client.run(conn, apply_op)
    refute_receive({^ref, :modified, ^resource_name}, 1000)

    # updating status does not change the generation
    {_, updated_resource} =
      updated_resource
      |> put_in([Access.key("status", %{}), "rand"], "foo")
      |> pop_in(~w(metadata managedFields))

    apply_op =
      K8s.Client.apply(
        "example.com/v1",
        "testresourcev3s/status",
        [namespace: "default", name: resource_name],
        updated_resource,
        field_manager: Bonny.Config.name()
      )

    {:ok, _} = K8s.Client.run(conn, apply_op)
    refute_receive({^ref, :modified, ^resource_name}, 1000)
  end

  # Skipped by default - run with --only reliability
  @tag :reliability
  test "callbacks are called reliably", %{conn: conn, timeout: timeout} do
    Enum.each(1..1000, fn run ->
      ref = make_ref()
      resource_name = "test-rel-#{run}"

      resource = IntegrationHelper.create_test_resource(resource_name, :v2, self(), ref)

      create_op = K8s.Client.create(resource)
      {:ok, _} = K8s.Client.run(conn, create_op)

      assert_receive(
        {^ref, :created, ^resource_name},
        timeout
      )
    end)
  end
end
