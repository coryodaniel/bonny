defmodule Bonny.Watcher.ImplTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Watcher.Impl

  defmodule Whizbang do
    @moduledoc false
    def add(evt), do: emit(:added, evt)
    def modify(evt), do: emit(:modified, evt)
    def delete(evt), do: emit(:deleted, evt)

    defp emit(type, evt) do
      send(self(), {type, evt})
      :ok
    end
  end

  describe "new/1" do
    test "returns the default state" do
      assert %Impl{controller: Widget, spec: %Bonny.CRD{}} = Impl.new(Widget)
    end
  end

  describe "set_resource_version/2" do
    test "sets the resource version from a watch event" do
      event = %{
        "object" => %{"metadata" => %{"resourceVersion" => "3"}}
      }

      state = Impl.new(Widget)
      new_state = Impl.set_resource_version(state, event)
      assert new_state.resource_version == 3
    end

    test "sets the resource version" do
      state = Impl.new(Widget)
      state = Map.put(state, :resource_version, 1)
      new_state = Impl.set_resource_version(state, 3)
      assert new_state.resource_version == 3
    end

    test "does not decrease the resource version" do
      state = Impl.new(Widget)
      state = Map.put(state, :resource_version, 200)
      new_state = Impl.set_resource_version(state, 3)
      assert new_state.resource_version == 200
    end
  end

  describe "watch_for_changes/2" do
    test "returns changes to a CRD resource" do
      added = Bonny.K8sMockClient.added_chunk()
      deleted = Bonny.K8sMockClient.deleted_chunk()

      state = Impl.new(Widget)
      state = %{state | resource_version: 1337}

      Impl.watch_for_changes(state, self())

      assert_receive %HTTPoison.AsyncChunk{chunk: ^added}, 1_000
      assert_receive %HTTPoison.AsyncChunk{chunk: ^deleted}, 1_000
    end
  end

  describe "parse_chunk/1" do
    test "strips whitespace and parses json" do
      chunk =
        "{\"type\":\"ADDED\",\"object\":{\"apiVersion\":\"example.com/v1\",\"kind\":\"Widget\",\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/last-applied-configuration\":\"{\\\"apiVersion\\\":\\\"example.com/v1\\\",\\\"kind\\\":\\\"Widget\\\",\\\"metadata\\\":{\\\"annotations\\\":{},\\\"name\\\":\\\"test-widget\\\",\\\"namespace\\\":\\\"default\\\"}}\\n\"},\"clusterName\":\"\",\"creationTimestamp\":\"2018-12-17T06:26:41Z\",\"generation\":1,\"name\":\"test-widget\",\"namespace\":\"default\",\"resourceVersion\":\"705460\",\"selfLink\":\"/apis/example.com/v1/namespaces/default/widgets/test-widget\",\"uid\":\"b7464e30-01c4-11e9-9066-025000000001\"}}}\n"

      result = Impl.parse_chunk(chunk)
      assert %{"type" => "ADDED"} = result
    end
  end

  describe "dispatch/2" do
    test "dispatches a kubernetes API event to the given module" do
      chunk =
        "{\"type\":\"ADDED\",\"object\":{\"apiVersion\":\"example.com/v1\",\"kind\":\"Widget\",\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/last-applied-configuration\":\"{\\\"apiVersion\\\":\\\"example.com/v1\\\",\\\"kind\\\":\\\"Widget\\\",\\\"metadata\\\":{\\\"annotations\\\":{},\\\"name\\\":\\\"test-widget\\\",\\\"namespace\\\":\\\"default\\\"}}\\n\"},\"clusterName\":\"\",\"creationTimestamp\":\"2018-12-17T06:26:41Z\",\"generation\":1,\"name\":\"test-widget\",\"namespace\":\"default\",\"resourceVersion\":\"705460\",\"selfLink\":\"/apis/example.com/v1/namespaces/default/widgets/test-widget\",\"uid\":\"b7464e30-01c4-11e9-9066-025000000001\"}}}\n"

      added_chunk = Impl.parse_chunk(chunk)
      Impl.dispatch(added_chunk, Whizbang)
      assert_received({:added, added_event})
    end
  end
end
