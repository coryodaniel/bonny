defmodule Bonny.Watcher.ImplTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Watcher.Impl
  doctest Bonny.Watcher.Impl

  describe "new/1" do
    test "returns the default state" do
      assert %Impl{controller: Widget, spec: %Bonny.CRD{}} = Impl.new(Widget)
    end
  end

  describe "get_resource_version/1" do
    test "returns the resource version when present" do
      rv = Impl.get_resource_version(%Impl{resource_version: "3"})
      assert rv == "3"
    end

    test "fetches the resource version when not present" do
      state = Impl.new(Widget)
      rv = Impl.get_resource_version(state)
      assert rv == "1337"
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

  describe "dispatch/2" do
    test "dispatches ADDED events to the given module's handler function" do
      evt = event("ADDED")
      Impl.dispatch(evt, Whizbang)

      # Professional.
      :timer.sleep(100)
      assert [event] = Whizbang.get(:added)
      assert %{"apiVersion" => "example.com/v1"} = event
    end

    test "dispatches MODIFIED events to the given module's handler function" do
      evt = event("MODIFIED")
      Impl.dispatch(evt, Whizbang)

      # Professional.
      :timer.sleep(100)
      assert [event] = Whizbang.get(:modified)
      assert %{"apiVersion" => "example.com/v1"} = event
    end

    test "dispatches DELETED events to the given module's handler function" do
      evt = event("DELETED")
      Impl.dispatch(evt, Whizbang)

      # Professional.
      :timer.sleep(100)
      assert [event] = Whizbang.get(:deleted)
      assert %{"apiVersion" => "example.com/v1"} = event
    end
  end

  defp event(type) do
    %{
      "object" => %{
        "apiVersion" => "example.com/v1",
        "kind" => "Widget",
        "metadata" => %{
          "name" => "test-widget",
          "namespace" => "default",
          "resourceVersion" => "705460"
        }
      },
      "type" => type
    }
  end
end
