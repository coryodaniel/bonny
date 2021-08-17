defmodule Bella.Server.WatcherTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bella.Server.Watcher
  doctest Bella.Server.Watcher

  defmodule TestWatcher do
    use Bella.Server.Watcher, client: Bella.K8sMockClient

    @impl true
    def watch_operation() do
      K8s.Client.list("watcher.test/v1", :foos)
    end

    @impl true
    def add(resource) do
      track_event(:add, resource)
    end

    @impl true
    def modify(resource) do
      track_event(:modify, resource)
    end

    @impl true
    def delete(resource) do
      track_event(:delete, resource)
    end

    @spec track_event(atom, map) :: :ok
    def track_event(type, resource) do
      event = {type, resource}
      Agent.update(TestWatcherCache, fn events -> [event | events] end)
    end
  end

  test "watch/3" do
    Agent.start_link(fn -> [] end, name: TestWatcherCache)
    {:ok, pid} = TestWatcher.start_link()
    rv = "3"

    Watcher.watch(TestWatcher, rv, pid)
    Process.sleep(500)

    events = Agent.get(TestWatcherCache, fn events -> events end)
    refute events == []
  end

  describe "dispatch/2" do
    test "dispatches ADDED events to the given module's handler function" do
      evt = event("ADDED")
      Watcher.dispatch(evt, Whizbang)

      # Professional.
      :timer.sleep(100)
      assert [event] = Whizbang.get(:added)
      assert %{"apiVersion" => "example.com/v1"} = event
    end

    test "dispatches MODIFIED events to the given module's handler function" do
      evt = event("MODIFIED")
      Watcher.dispatch(evt, Whizbang)

      # Professional.
      :timer.sleep(100)
      assert [event] = Whizbang.get(:modified)
      assert %{"apiVersion" => "example.com/v1"} = event
    end

    test "dispatches DELETED events to the given module's handler function" do
      evt = event("DELETED")
      Watcher.dispatch(evt, Whizbang)

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
