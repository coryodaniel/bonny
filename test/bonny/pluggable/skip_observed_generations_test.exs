defmodule Bonny.Pluggable.SkipObservedGenerationsTest do
  use ExUnit.Case
  use Bonny.Axn.Test

  alias Bonny.Pluggable.SkipObservedGenerations, as: MUT

  def gen_test_axn(
        action,
        generation,
        observed_generation,
        observed_generation_key \\ [Access.key("status", %{}), "observedGeneration"]
      ) do
    generation_key = ~w(metadata generation)

    axn = axn(action)

    %{
      axn
      | resource:
          axn.resource
          |> put_in(generation_key, generation)
          |> put_in(observed_generation_key, observed_generation)
    }
  end

  test "default options" do
    opts = MUT.init()

    # generation already observed
    assert halted?(MUT.call(gen_test_axn(:add, 1, 1), opts))
    assert halted?(MUT.call(gen_test_axn(:modify, 1, 1), opts))
    refute halted?(MUT.call(gen_test_axn(:delete, 1, 1), opts))
    refute halted?(MUT.call(gen_test_axn(:reconcile, 1, 1), opts))

    # generation not observed
    refute halted?(MUT.call(gen_test_axn(:add, 1, 2), opts))
    refute halted?(MUT.call(gen_test_axn(:modify, 1, 2), opts))
    refute halted?(MUT.call(gen_test_axn(:delete, 1, 2), opts))
    refute halted?(MUT.call(gen_test_axn(:reconcile, 1, 2), opts))
  end

  test "custom list of actions" do
    opts = MUT.init(actions: [:add, :modify, :reconcile])

    # generation already observed
    assert halted?(MUT.call(gen_test_axn(:add, 1, 1), opts))
    assert halted?(MUT.call(gen_test_axn(:modify, 1, 1), opts))
    assert halted?(MUT.call(gen_test_axn(:reconcile, 1, 1), opts))
    refute halted?(MUT.call(gen_test_axn(:delete, 1, 1), opts))

    # generation not observed
    refute halted?(MUT.call(gen_test_axn(:add, 1, 2), opts))
    refute halted?(MUT.call(gen_test_axn(:modify, 1, 2), opts))
    refute halted?(MUT.call(gen_test_axn(:delete, 1, 2), opts))
    refute halted?(MUT.call(gen_test_axn(:reconcile, 1, 2), opts))
  end

  test "custom key for observed generation" do
    observed_generation_key = [
      Access.key("status", %{}),
      Access.key("int", %{}),
      "observedGeneration"
    ]

    opts = MUT.init(observed_generation_key: ~w(int observedGeneration))

    # generation already observed
    assert halted?(MUT.call(gen_test_axn(:add, 1, 1, observed_generation_key), opts))
    assert halted?(MUT.call(gen_test_axn(:modify, 1, 1, observed_generation_key), opts))
    refute halted?(MUT.call(gen_test_axn(:reconcile, 1, 1, observed_generation_key), opts))
    refute halted?(MUT.call(gen_test_axn(:delete, 1, 1, observed_generation_key), opts))

    # generation not observed
    refute halted?(MUT.call(gen_test_axn(:add, 1, 2, observed_generation_key), opts))
    refute halted?(MUT.call(gen_test_axn(:modify, 1, 2, observed_generation_key), opts))
    refute halted?(MUT.call(gen_test_axn(:delete, 1, 2, observed_generation_key), opts))
    refute halted?(MUT.call(gen_test_axn(:reconcile, 1, 2, observed_generation_key), opts))
  end
end
