defmodule Bonny.Pluggable.AddMissingGVKTest do
  use ExUnit.Case, async: true
  use Bonny.Axn.Test

  import YamlElixir.Sigil

  alias Bonny.Pluggable.AddMissingGVK, as: MUT

  test "adds apiVersion and kind fields to the resource" do
    opts = MUT.init(apiVersion: "v1", kind: "ConfigMap")

    resource = ~y"""
    metadata:
      name: foo
      namespace: default
    data:
      key: value
    """

    result = MUT.call(axn(:add, resource: resource), opts)

    # generation already observed
    assert "v1" == result.resource["apiVersion"]
    assert "ConfigMap" == result.resource["kind"]
  end
end
