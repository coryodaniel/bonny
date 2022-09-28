defmodule <%= app_name %>.Controller.<%= controller_name %>Test do
  @moduledoc false
  use ExUnit.Case, async: false
  alias <%= app_name %>.Controller.<%= controller_name %>

  describe "add/1" do
    test "returns :ok" do
      event = %{}
      result = <%= controller_name %>.add(event)
      assert result == :ok
    end
  end

  describe "modify/1" do
    test "returns :ok" do
      event = %{}
      result = <%= controller_name %>.modify(event)
      assert result == :ok
    end
  end

  describe "reconcile/1" do
    test "returns :ok" do
      event = %{}
      result = <%= controller_name %>.reconcile(event)
      assert result == :ok
    end
  end

  describe "delete/1" do
    test "returns :ok" do
      event = %{}
      result = <%= controller_name %>.delete(event)
      assert result == :ok
    end
  end
end
