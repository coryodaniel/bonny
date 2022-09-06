defmodule <%= app_name %>.Controller.<%= mod_name %>Test do
  @moduledoc false
  use ExUnit.Case, async: false
  alias <%= app_name %>.Controller.<%= mod_name %>

  describe "apply/1" do
    test "returns :ok" do
      event = %{}
      result = <%= mod_name %>.apply(event)
      assert result == :ok
    end
  end

  describe "delete/1" do
    test "returns :ok" do
      event = %{}
      result = <%= mod_name %>.delete(event)
      assert result == :ok
    end
  end
end
