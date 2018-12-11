defmodule BonnyTest do
  use ExUnit.Case
  doctest Bonny

  test "greets the world" do
    assert Bonny.hello() == :world
  end
end
