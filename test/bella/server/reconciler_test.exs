defmodule Bella.Server.ReconcilerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bella.Server.Reconciler

  defmodule TestReconciler do
    use Bella.Server.Reconciler, frequency: 15, client: Bella.K8sMockClient

    @impl true
    def reconcile(%{} = resource) do
      Agent.update(TestReconcilerCache, fn resources -> [resource | resources] end)
      :ok
    end

    @impl true
    def reconcile_operation() do
      K8s.Client.list("reconciler.test.foos/v1", :foos)
    end
  end

  defmodule TestReconcilerErrors do
    use Bella.Server.Reconciler, frequency: 15, client: Bella.K8sMockClient

    @impl Bella.Server.Reconciler
    def reconcile(%{} = resource) do
      Agent.update(TestReconcilerCacheErr, fn resources -> [resource | resources] end)
      :ok
    end

    @impl Bella.Server.Reconciler
    def reconcile_operation() do
      K8s.Client.list("reconciler.test.errors/v1", :foos)
    end
  end

  test "schedule/2 sends `:run` after delay" do
    Reconciler.schedule(self(), 1)
    assert_receive :run, 2_000
  end

  describe "run/1" do
    test "happy path" do
      Agent.start_link(fn -> [] end, name: TestReconcilerCache)
      Reconciler.run(TestReconciler)
      Process.sleep(10)

      resources = Agent.get(TestReconcilerCache, fn resources -> resources end)

      names =
        resources
        |> Enum.map(fn %{"name" => name} -> name end)
        |> Enum.sort()

      assert names == ["bar", "foo"]
    end

    @tag :wip
    test "Handles a stream with errors" do
      Agent.start_link(fn -> [] end, name: TestReconcilerCacheErr)
      Reconciler.run(TestReconcilerErrors)
      Process.sleep(10)

      resources = Agent.get(TestReconcilerCacheErr, fn resources -> resources end)

      assert [%{"name" => "bar"}] == resources
    end
  end
end
