defmodule Bonny.Server.ReconcilerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Server.Reconciler

  defmodule TestReconciler do
    use Bonny.Server.Reconciler, frequency: 15, client: Bonny.K8sMockClient

    @impl true
    def reconcile(pod) do
      Agent.update(TestReconcilerCache, fn pods -> [pod | pods] end)
      :ok
    end

    @impl true
    def reconcile_operation() do
      K8s.Client.list("reconciler.test/v1", :foos)
    end
  end

  test "schedule/2 sends `:run` after delay" do
    Reconciler.schedule(self(), 1)
    assert_receive :run, 2_000
  end

  test "run/1" do
    Agent.start_link(fn -> [] end, name: TestReconcilerCache)
    Reconciler.run(TestReconciler)
    Process.sleep(500)

    pods = Agent.get(TestReconcilerCache, fn pods -> pods end)

    names =
      pods
      |> Enum.map(fn %{"name" => name} -> name end)
      |> Enum.sort()

    assert names == ["bar", "foo"]
  end
end
