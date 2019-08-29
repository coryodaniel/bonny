defmodule Bonny.Watcher.ImplTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Watcher.Impl
  doctest Bonny.Watcher.Impl

  describe "new/1" do
    test "returns the default state" do
      assert %Impl{controller: Widget, spec: %Bonny.CRD{}} = Impl.new(Widget)
    end
  end

  describe "get_resource_version/1" do
    test "returns the resource version when present" do
      rv = Impl.get_resource_version(%Impl{resource_version: "3"})
      assert rv == "3"
    end
  end

  describe "watch_for_changes/2" do
    test "returns changes to a CRD resource" do
      added = Bonny.K8sMockClient.added_chunk()
      deleted = Bonny.K8sMockClient.deleted_chunk()

      state = Impl.new(Widget)
      state = %{state | resource_version: 1337}

      Impl.watch_for_changes(state, self())

      assert_receive %HTTPoison.AsyncChunk{chunk: ^added}, 1_000
      assert_receive %HTTPoison.AsyncChunk{chunk: ^deleted}, 1_000
    end
  end
end
