defmodule BonnyTest do
  @moduledoc false
  use ExUnit.Case, async: false

  describe "namespace/0" do
    test "returns 'default' when not set" do
      assert Bonny.namespace() == "default"
    end

    test "can be set by env variable" do
      System.put_env("BONNY_POD_NAMESPACE", "prod")
      assert Bonny.namespace() == "prod"
      System.delete_env("BONNY_POD_NAMESPACE")
    end
  end
end
