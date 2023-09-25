defmodule Bonny.AxnTest do
  use ExUnit.Case, async: true

  alias Bonny.Axn, as: MUT

  alias Bonny.Test.ResourceHelper

  setup do
    conn = Bonny.Config.conn()

    ref = make_ref()

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
        "bar" => "lorem ipsum",
        "ref" => ResourceHelper.to_string(ref),
        "pid" => ResourceHelper.to_string(self())
      }
    }

    [
      axn: MUT.new!(action: :add, resource: resource, conn: conn),
      related: related,
      ref: ref
    ]
  end

  describe "event/5 resp. event/6" do
    test "adds an without related object to an empty list of events", %{axn: axn} do
      result_axn =
        MUT.register_event(axn, :Normal, "Reason for the action", "add", "Custom Event Message")

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
        MUT.register_event(
          axn,
          related,
          :Normal,
          "Reason for the action",
          "add",
          "Custom Event Message"
        )

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
        MUT.register_event(
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

  describe "failure_event/2" do
    test "creates default event", %{axn: axn} do
      result_axn = MUT.failure_event(axn)

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
        MUT.failure_event(axn, message: "Custom Success Message", reason: "Custom Reason")

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
        MUT.failure_event(axn, action: "modify", event_type: :Warning, regarding: related)

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
    test "raises StatusAlreadyAppliedError if status already applied", %{axn: axn} do
      assert_raise Bonny.Axn.StatusAlreadyAppliedError, fn ->
        axn
        |> MUT.apply_status()
        |> MUT.update_status(&Function.identity/1)
      end
    end

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

  describe "apply_status/2" do
    defmodule ApplyStatusK8sMock do
      require Logger
      import K8s.Client.HTTPTestHelper
      alias Bonny.Test.ResourceHelper

      def request(
            :patch,
            %URI{path: "api/v1/namespaces/default/configmaps/foo/status"},
            body,
            _headers,
            _opts
          ) do
        resource = Jason.decode!(body)
        send(self(), resource["status"]["ref"] |> ResourceHelper.string_to_ref())
        render(resource)
      end

      def request(_method, _uri, _body, _headers, _opts) do
        Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
        {:error, %K8s.Client.HTTPError{message: "request not mocked"}}
      end
    end

    setup do
      K8s.Client.DynamicHTTPProvider.register(self(), ApplyStatusK8sMock)
    end

    test "applies the status to the cluster", %{axn: axn, ref: ref} do
      axn
      |> MUT.update_status(fn _ -> %{"ref" => ResourceHelper.to_string(ref)} end)
      |> MUT.apply_status()

      assert_receive ^ref
    end

    test "calls registered callbacks", %{axn: axn, ref: ref} do
      axn
      |> MUT.register_before_apply_status(fn resource, axn ->
        assert is_struct(axn, Bonny.Axn)
        send(self(), {:callback, resource["status"]["ref"] |> ResourceHelper.string_to_ref()})
        resource
      end)
      |> MUT.update_status(fn _ -> %{"ref" => ResourceHelper.to_string(ref)} end)
      |> MUT.apply_status()

      assert_receive {:callback, ^ref}
      assert_receive ^ref
    end

    test "does not call registered callbacks if status is nil", %{axn: axn, ref: ref} do
      axn
      |> MUT.register_before_apply_status(fn resource, axn ->
        assert is_struct(axn, Bonny.Axn)
        send(self(), {:callback, resource["status"]["ref"] |> ResourceHelper.string_to_ref()})
        resource
      end)
      |> MUT.apply_status()

      refute_receive {:callback, ^ref}
      refute_receive ^ref
    end

    test "raises when alredy applied", %{axn: axn, ref: ref} do
      assert_raise Bonny.Axn.StatusAlreadyAppliedError, fn ->
        axn
        |> MUT.update_status(fn _ -> %{"ref" => ResourceHelper.to_string(ref)} end)
        |> MUT.apply_status()
        |> MUT.apply_status()
      end
    end
  end

  describe "register_descendant/3" do
    test "registers a descendant with owner reference", %{axn: axn, related: related} do
      %{descendants: descendants} = MUT.register_descendant(axn, related)
      [{_, registered_descendant} | others] = Map.values(descendants)

      assert Enum.empty?(others)

      assert K8s.Resource.FieldAccessors.name(registered_descendant) ==
               K8s.Resource.FieldAccessors.name(related)

      assert K8s.Resource.FieldAccessors.namespace(registered_descendant) ==
               K8s.Resource.FieldAccessors.namespace(related)

      assert K8s.Resource.FieldAccessors.kind(registered_descendant) ==
               K8s.Resource.FieldAccessors.kind(related)

      assert K8s.Resource.FieldAccessors.api_version(registered_descendant) ==
               K8s.Resource.FieldAccessors.api_version(related)

      assert is_list(registered_descendant["metadata"]["ownerReferences"])
      assert length(registered_descendant["metadata"]["ownerReferences"]) == 1
    end

    test "Ommits owner reference if requested", %{axn: axn, related: related} do
      %{descendants: descendants} = MUT.register_descendant(axn, related, omit_owner_ref: true)
      [{_, registered_descendant} | []] = Map.values(descendants)
      assert is_nil(registered_descendant["metadata"]["ownerReferences"])
    end

    test "raises DescendantsAlreadyAppliedError if descendants already applied", %{
      axn: axn,
      related: related
    } do
      assert_raise Bonny.Axn.DescendantsAlreadyAppliedError, fn ->
        axn
        |> MUT.apply_descendants()
        |> MUT.register_descendant(related)
      end
    end
  end

  describe "apply_descendant/2" do
    defmodule ApplyDescendantsK8sMock do
      require Logger
      import K8s.Client.HTTPTestHelper
      alias Bonny.Test.ResourceHelper

      def request(
            :patch,
            %URI{path: "api/v1/namespaces/default/configmaps/bar"},
            body,
            _headers,
            _opts
          ) do
        resource = Jason.decode!(body)
        ref = resource["data"]["ref"] |> ResourceHelper.string_to_ref()
        pid = resource["data"]["pid"] |> ResourceHelper.string_to_pid()
        send(pid, ref)
        render(resource)
      end

      def request(_method, _uri, _body, _headers, _opts) do
        Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
        {:error, %K8s.Client.HTTPError{message: "request not mocked"}}
      end
    end

    setup do
      K8s.Client.DynamicHTTPProvider.register(self(), ApplyDescendantsK8sMock)
    end

    test "applies descendants", %{axn: axn, related: related, ref: ref} do
      axn
      |> MUT.register_descendant(related)
      |> MUT.apply_descendants()

      assert_receive ^ref
    end

    test "raises if already applied", %{axn: axn} do
      assert_raise Bonny.Axn.DescendantsAlreadyAppliedError, fn ->
        axn
        |> MUT.apply_descendants()
        |> MUT.apply_descendants()
      end
    end

    test "runs registered callbacks", %{axn: axn, related: related, ref: ref} do
      axn
      |> MUT.register_before_apply_descendants(fn resources, axn ->
        assert is_struct(axn, Bonny.Axn)
        send(self(), {:callback, hd(resources)["data"]["ref"] |> ResourceHelper.string_to_ref()})
        resources
      end)
      |> MUT.register_descendant(related)
      |> MUT.apply_descendants()

      assert_receive {:callback, ^ref}
      assert_receive ^ref
    end
  end

  describe "set_condition/4" do
    test "Sets conditions on a fresh resource", %{axn: axn} do
      axn =
        axn
        |> MUT.set_condition("Ready", false, "working on it...")
        |> MUT.set_condition("Initialized", true, "Initialization done")

      assert 2 == length(axn.status["conditions"])
    end

    test "Updates lastHeartbeatTime", %{axn: axn} do
      axn =
        axn
        |> MUT.set_condition("Ready", false, "working on it...")
        |> MUT.set_condition("Ready", false, "working on it...")

      assert 1 == length(axn.status["conditions"])
      ready_condition = hd(axn.status["conditions"])
      assert ready_condition["lastHeartbeatTime"] > ready_condition["lastTransitionTime"]
    end

    test "Updates lastTransitionTime", %{axn: axn} do
      axn =
        axn
        |> MUT.set_condition("Ready", false, "working on it...")
        |> MUT.set_condition("Ready", true, "working on it...")

      assert 1 == length(axn.status["conditions"])
      ready_condition = hd(axn.status["conditions"])
      assert ready_condition["lastHeartbeatTime"] == ready_condition["lastTransitionTime"]
    end
  end
end
