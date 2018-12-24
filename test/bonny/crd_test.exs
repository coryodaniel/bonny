defmodule Bonny.CRDTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.CRD

  describe "to_manifest/1" do
    test "generates a kubernetes manifest" do
      spec = Widget.crd_spec()
      manifest = CRD.to_manifest(spec)

      expected = %{
        apiVersion: "apiextensions.k8s.io/v1beta1",
        kind: "CustomResourceDefinition",
        metadata: %{
          name: "widgets.bonny.test",
          labels: %{"k8s-app" => "bonny"}
        },
        spec: %Bonny.CRD{
          group: "bonny.test",
          names: %{kind: "Widget", plural: "widgets", short_names: nil, singular: "widget"},
          scope: "Namespaced",
          version: "v1"
        }
      }

      assert expected == manifest
    end
  end

  describe "list_path/1" do
    test "returns the cluster-wide URL path to list a CRD's resources" do
      widget = Widget.crd_spec()
      widget = %{widget | scope: :cluster}
      path = CRD.list_path(widget)

      assert path == "/apis/bonny.test/v1/widgets"
    end

    test "returns the namespaced URL path to list a CRD's resources" do
      widget = Widget.crd_spec()
      path = CRD.list_path(widget)

      assert path == "/apis/bonny.test/v1/namespaces/default/widgets"
    end
  end

  describe "watch_path/2" do
    test "returns the cluster-wide URL path to watch a CRD" do
      widget = Widget.crd_spec()
      widget = %{widget | scope: :cluster}
      path = CRD.watch_path(widget, 30_010)

      assert path == "/apis/bonny.test/v1/widgets?resourceVersion=30010&watch=true"
    end

    test "returns the namespaced URL path to list a CRD's resources" do
      widget = Widget.crd_spec()
      path = CRD.watch_path(widget, 30_010)

      assert path ==
               "/apis/bonny.test/v1/namespaces/default/widgets?resourceVersion=30010&watch=true"
    end
  end

  describe "read_path/2" do
    test "returns the cluster-wide URL path to read a CRD resource" do
      widget = Widget.crd_spec()
      widget = %{widget | scope: :cluster}
      path = CRD.read_path(widget, "test-widget")

      assert path == "/apis/bonny.test/v1/widgets/test-widget"
    end

    test "returns the namespaced URL path to read a CRD resource" do
      widget = Widget.crd_spec()
      path = CRD.read_path(widget, "test-widget")

      assert path == "/apis/bonny.test/v1/namespaces/default/widgets/test-widget"
    end
  end
end
