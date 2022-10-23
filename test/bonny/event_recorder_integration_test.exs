defmodule Bonny.EventRecorderIntegrationTest do
  use ExUnit.Case, async: true

  alias Bonny.Test.IntegrationHelper

  alias Bonny.EventRecorder, as: MUT

  setup_all do
    conn = IntegrationHelper.conn()
    start_supervised!({MUT, operator: __MODULE__})

    on_exit(fn ->
      delete_op =
        K8s.Client.delete("v1", "ConfigMap",
          namespace: "default",
          name: "event-test"
        )

      {:ok, _} = K8s.Client.run(conn, delete_op)
    end)

    [conn: conn]
  end

  describe "emit/3" do
    @tag :integration
    test "should create the event", %{conn: conn} do
      resource = %{
        "apiVersion" => "v1",
        "kind" => "ConfigMap",
        "metadata" => %{"name" => "event-test", "namespace" => "default"}
      }

      apply_op = K8s.Client.apply(resource, field_manager: "bonny", force: true)
      {:ok, resource} = K8s.Client.run(conn, apply_op)

      event = Bonny.Event.new!(resource, nil, :Normal, "testing", "test", "All good")
      MUT.emit(event, __MODULE__, conn)
      MUT.emit(event, __MODULE__, conn)
      MUT.emit(event, __MODULE__, conn)

      #  get the event where regarding.uid == the uid of the resource
      get_op =
        K8s.Client.list("events.k8s.io/v1", "Event")
        |> K8s.Operation.put_query_param(
          :fieldSelector,
          "regarding.uid=#{resource["metadata"]["uid"]}"
        )

      {:ok, events} = K8s.Client.run(conn, get_op)

      assert Map.has_key?(events, "items")

      items =
        Enum.filter(
          events["items"],
          &(&1["metadata"]["name"] =~ "event-test" && &1["action"] == "test")
        )

      assert 1 == length(items)

      assert 3 ==
               items |> Enum.find(&(&1["action"] == "test")) |> get_in(~w(series count))
    end
  end
end
