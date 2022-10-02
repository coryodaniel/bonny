defmodule Mix.Tasks.Bonny.Gen.Manifest.<%= assigns[:app_name] %>CustomizerTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Bonny.Gen.Manifest.<%= assigns[:app_name] %>Customizer, as: MUT

  describe "override/1" do
    test "fallback returns passed argument" do
      test_map = %{random_number: Enum.random(0..255)}
      assert test_map == MUT.override(test_map)
    end
  end

end
