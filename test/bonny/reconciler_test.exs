defmodule Bonny.ReconcilerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Reconciler

  describe "run/2" do
    test "dispatches to the controllers reconcile handler" do
      Reconciler.run(Whizbang)

      # Professional.
      :timer.sleep(100)

      events = Whizbang.get(:reconciled)
      assert events == [%{"page" => 2}, %{"page" => 1}]
    end
  end
end
