defmodule <%= app_name %>.Controller.<%= controller_name %>Test do
  @moduledoc false
  use ExUnit.Case, async: false
  use Bonny.Axn.Test

  alias <%= app_name %>.Controller.<%= controller_name %>

  test "add is handled and returns axn" do
    axn = axn(:add)
    result = <%= controller_name %>.call(axn, [])
    assert is_struct(result, Bonny.Axn)
  end

  test "modify is handled and returns axn" do
    axn = axn(:modify)
    result = <%= controller_name %>.call(axn, [])
    assert is_struct(result, Bonny.Axn)
  end

  test "reconcile is handled and returns axn" do
    axn = axn(:reconcile)
    result = <%= controller_name %>.call(axn, [])
    assert is_struct(result, Bonny.Axn)
  end

  test "delete is handled and returns axn" do
    axn = axn(:delete)
    result = <%= controller_name %>.call(axn, [])
    assert is_struct(result, Bonny.Axn)
  end
end
