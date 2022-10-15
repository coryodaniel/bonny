defmodule Bonny.AxnTest do
  use ExUnit.Case, async: true

  alias Bonny.Axn, as: MUT

  setup do
    conn = Bonny.Config.conn()

    resource = %{
      "apiVersion" => "v1",
      "kind" => "ConfigMap",
      "metadata" => %{
        "name" => "foo",
        "namespace" => "default",
        "uid" => "foo-uid"
      },
      "data" => %{
        "foo" => "lorem ipsum"
      }
    }

    related = %{
      "apiVersion" => "v1",
      "kind" => "ConfigMap",
      "metadata" => %{
        "name" => "bar",
        "namespace" => "default",
        "uid" => "bar-uid"
      },
      "data" => %{
        "bar" => "lorem ipsum"
      }
    }

    [
      axn: MUT.new!(action: :add, resource: resource, conn: conn),
      related: related
    ]
  end

  describe "event/5 resp. event/6" do
    test "adds an without related object to an empty list of events", %{axn: axn} do
      result_axn = MUT.event(axn, :Normal, "Reason for the action", "add", "Custom Event Message")

      assert 1 == length(result_axn.events)

      assert match?(
               %Bonny.Event{
                 action: "add",
                 event_type: :Normal,
                 message: "Custom Event Message",
                 now: %DateTime{},
                 reason: "Reason for the action",
                 regarding: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "foo",
                   "namespace" => "default",
                   "uid" => "foo-uid"
                 },
                 related: nil
               },
               hd(result_axn.events)
             )
    end

    test "adds an event with related object to an empty list of events", %{
      axn: axn,
      related: related
    } do
      result_axn =
        MUT.event(axn, related, :Normal, "Reason for the action", "add", "Custom Event Message")

      assert 1 == length(result_axn.events)

      assert match?(
               %Bonny.Event{
                 action: "add",
                 event_type: :Normal,
                 message: "Custom Event Message",
                 now: %DateTime{},
                 reason: "Reason for the action",
                 regarding: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "foo",
                   "namespace" => "default",
                   "uid" => "foo-uid"
                 },
                 related: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "bar",
                   "namespace" => "default",
                   "uid" => "bar-uid"
                 }
               },
               hd(result_axn.events)
             )
    end

    test "appends an event to an existing list of events", %{axn: axn} do
      dummy_event =
        Bonny.Event.new!(
          action: :add,
          event_type: :Normal,
          message: "Foo",
          reason: "Bar",
          regarding: axn.resource
        )

      result_axn =
        MUT.event(
          struct!(axn, events: [dummy_event]),
          :Normal,
          "Reason for the action",
          "add",
          "Custom Event Message"
        )

      assert 2 == length(result_axn.events)
    end
  end

  describe "success_event/2" do
    test "creates default event", %{axn: axn} do
      result_axn = MUT.success_event(axn)

      assert 1 == length(result_axn.events)

      assert match?(
               %Bonny.Event{
                 action: "add",
                 event_type: :Normal,
                 message: "Resource add was successful.",
                 now: %DateTime{},
                 reason: "Successful Add",
                 regarding: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "foo",
                   "namespace" => "default",
                   "uid" => "foo-uid"
                 },
                 related: nil
               },
               hd(result_axn.events)
             )
    end

    test "creates event with custom messages", %{axn: axn} do
      result_axn =
        MUT.success_event(axn, message: "Custom Success Message", reason: "Custom Reason")

      assert 1 == length(result_axn.events)

      assert match?(
               %Bonny.Event{
                 action: "add",
                 event_type: :Normal,
                 message: "Custom Success Message",
                 now: %DateTime{},
                 reason: "Custom Reason",
                 regarding: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "foo",
                   "namespace" => "default",
                   "uid" => "foo-uid"
                 },
                 related: nil
               },
               hd(result_axn.events)
             )
    end

    test "does not override other fields", %{axn: axn, related: related} do
      result_axn =
        MUT.success_event(axn, action: "modify", event_type: :Warning, regarding: related)

      assert 1 == length(result_axn.events)

      assert match?(
               %Bonny.Event{
                 action: "add",
                 event_type: :Normal,
                 message: "Resource add was successful.",
                 now: %DateTime{},
                 reason: "Successful Add",
                 regarding: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "foo",
                   "namespace" => "default",
                   "uid" => "foo-uid"
                 },
                 related: nil
               },
               hd(result_axn.events)
             )
    end
  end

  describe "failed_event/2" do
    test "creates default event", %{axn: axn} do
      result_axn = MUT.failed_event(axn)

      assert 1 == length(result_axn.events)

      assert match?(
               %Bonny.Event{
                 action: "add",
                 event_type: :Warning,
                 message: "Resource add has failed, no reason as specified.",
                 now: %DateTime{},
                 reason: "Failed Add",
                 regarding: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "foo",
                   "namespace" => "default",
                   "uid" => "foo-uid"
                 },
                 related: nil
               },
               hd(result_axn.events)
             )
    end

    test "creates event with custom messages", %{axn: axn} do
      result_axn =
        MUT.failed_event(axn, message: "Custom Success Message", reason: "Custom Reason")

      assert 1 == length(result_axn.events)

      assert match?(
               %Bonny.Event{
                 action: "add",
                 event_type: :Warning,
                 message: "Custom Success Message",
                 now: %DateTime{},
                 reason: "Custom Reason",
                 regarding: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "foo",
                   "namespace" => "default",
                   "uid" => "foo-uid"
                 },
                 related: nil
               },
               hd(result_axn.events)
             )
    end

    test "does not override other fields", %{axn: axn, related: related} do
      result_axn =
        MUT.failed_event(axn, action: "modify", event_type: :Warning, regarding: related)

      assert 1 == length(result_axn.events)

      assert match?(
               %Bonny.Event{
                 action: "add",
                 event_type: :Warning,
                 message: "Resource add has failed, no reason as specified.",
                 now: %DateTime{},
                 reason: "Failed Add",
                 regarding: %{
                   "apiVersion" => "v1",
                   "kind" => "ConfigMap",
                   "name" => "foo",
                   "namespace" => "default",
                   "uid" => "foo-uid"
                 },
                 related: nil
               },
               hd(result_axn.events)
             )
    end
  end

  describe "update_status/2" do
    test "Passes an empty map to the update function if neither axn nor axn.resource contain a status",
         %{axn: axn} do
      MUT.update_status(
        axn,
        fn status ->
          assert status == %{}
        end
      )
    end

    test "Passes status of resource to the update function if it is defined.",
         %{axn: axn} do
      %{axn | resource: %{"status" => :resource_status}}
      |> MUT.update_status(fn status ->
        assert status == :resource_status
      end)
    end

    test "Passes defined in axn to the update function if it is defined.",
         %{axn: axn} do
      %{axn | resource: %{"status" => :resource_status}, status: :axn_status}
      |> MUT.update_status(fn status ->
        assert status == :axn_status
      end)
    end

    test "Updates axn.status with the result of the callback",
         %{axn: axn} do
      axn =
        %{axn | resource: %{"status" => :resource_status}, status: :axn_status}
        |> MUT.update_status(fn _ ->
          :result
        end)

      assert axn.status == :result
    end
  end
end
