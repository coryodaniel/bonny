defmodule Bonny.Server.ReconcilerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Server.Reconciler

  defmodule TestReconciler do
    use Bonny.Server.Reconciler, frequency: 15

    @impl true
    def reconcile(pod) do
      Agent.update(TestReconcilerCache, fn pods -> [pod | pods] end)
      :ok
    end

    @impl true
    def reconcile_resources() do
      {:ok,
       [
         %{"name" => "foo"},
         %{"name" => "bar"}
       ]}
    end
  end

  test "schedule/2 sends `:run` after N seconds" do
    Reconciler.schedule(self(), 1)
    assert_receive :run, 2_000
  end

  describe "run/1" do
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
