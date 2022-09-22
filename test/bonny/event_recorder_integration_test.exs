defmodule Bonny.EventRecorderIntegrationTest do
  use ExUnit.Case, async: true

  alias Bonny.Test.IntegrationHelper

  alias Bonny.EventRecorder, as: MUT

  setup_all do
    conn = IntegrationHelper.conn()
    Supervisor.start_link([{MUT, name: MUT, conn: conn}], strategy: :one_for_one)

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

  describe "event/7" do
    @tag :integration
    test "should create the event", %{conn: conn} do
      resource = %{
        "apiVersion" => "v1",
        "kind" => "ConfigMap",
        "metadata" => %{"name" => "event-test", "namespace" => "default"}
      }

      apply_op = K8s.Client.apply(resource, field_manager: "bonny", force: true)
      {:ok, resource} = K8s.Client.run(conn, apply_op)

      MUT.event(MUT, resource, nil, :Normal, "testing", "test", "All good")
      MUT.event(MUT, resource, nil, :Normal, "testing", "test", "All good")
      MUT.event(MUT, resource, nil, :Normal, "testing", "test", "All good")

      #  get the event where regarding.uid == the uid of the resource
      get_op =
        K8s.Client.list("events.k8s.io/v1", "Event")
        |> K8s.Operation.put_query_param(
          :fieldSelector,
          "regarding.uid=#{resource["metadata"]["uid"]}"
        )

      {:ok, events} = K8s.Client.run(conn, get_op)

      assert Map.has_key?(events, "items")
      assert 1 == length(events["items"])
      assert 3 == events["items"] |> hd |> get_in(~w(series count))
    end
  end
end
