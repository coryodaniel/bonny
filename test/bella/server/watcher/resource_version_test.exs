defmodule Bella.Server.Watcher.ResourceVersionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bella.Server.Watcher.ResourceVersion

  test "get/1 returns the resourceVersion for an operation" do
    operation = K8s.Client.list("resourceVersion.test/v1", :foos)
    rv = ResourceVersion.get(operation)
    assert rv == {:ok, "1337"}
  end
end
