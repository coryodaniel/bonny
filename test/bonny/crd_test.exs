defmodule Bonny.CRDTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Bonny.CRD
  alias Bonny.CRD

  describe "to_manifest/1" do
    test "generates a kubernetes manifest" do
      spec = Widget.crd_spec()
      manifest = CRD.to_manifest(spec)

      expected = %{
        apiVersion: "apiextensions.k8s.io/v1beta1",
        kind: "CustomResourceDefinition",
        metadata: %{
          name: "widgets.example.com",
          labels: %{"k8s-app" => "bonny"}
        },
        spec: %Bonny.CRD{
          group: "example.com",
          names: %{kind: "Widget", plural: "widgets", shortNames: nil, singular: "widget"},
          scope: "Namespaced",
          version: "v1"
        }
      }

      assert expected == manifest
    end
  end
end
