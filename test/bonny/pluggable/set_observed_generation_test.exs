defmodule Bonny.Pluggable.SetObservedGenerationTest do
  use ExUnit.Case
  use Bonny.Axn.Test

  alias Bonny.Pluggable.SetObservedGeneration, as: MUT

  def gen_test_axn(generation) do
    generation_key = ~w(metadata generation)

    axn = axn(:add)

    %{
      axn
      | resource:
          axn.resource
          |> put_in(generation_key, generation)
    }
  end

  test "default options" do
    opts = MUT.init()

    assert MUT.call(gen_test_axn(1), opts).status["observedGeneration"] == 1
  end

  test "noop if no observed generation" do
    opts = MUT.init()

    axn = gen_test_axn(nil)
    assert MUT.call(axn, opts) == axn
  end

  test "custom key for observed generation" do
    opts = MUT.init(observed_generation_key: ~w(int observedGeneration))

    assert MUT.call(gen_test_axn(1), opts).status["int"]["observedGeneration"] == 1
  end

  test "custom key for observed generation built with Access.key()" do
    opts = MUT.init(observed_generation_key: [Access.key("int", %{}), "observedGeneration"])

    assert MUT.call(gen_test_axn(1), opts).status["int"]["observedGeneration"] == 1
  end
end
