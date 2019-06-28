defmodule Bonny.Server.SchedulerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Server.Scheduler
  doctest Bonny.Server.Scheduler
  doctest Bonny.Server.Scheduler.Binding

  defmodule TestScheduler do
    use Bonny.Server.Scheduler, name: "test-scheduler"

    def select_node_for_pod(_pod, nodes) do
      nodes
      |> Enum.take(1)
      |> List.first()
    end
  end

  describe "using" do
    test "field_selector/0" do
      assert TestScheduler.field_selector() == "spec.schedulerName=test-scheduler,spec.nodeName="
    end

    test "name/0" do
      assert TestScheduler.name() == "test-scheduler"
    end
  end

  test "field_selector/1" do
    assert Scheduler.field_selector("foo") == "spec.schedulerName=foo,spec.nodeName="
  end
end
