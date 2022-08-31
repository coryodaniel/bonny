defmodule Bonny.CRDTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Bonny.CRD
  alias Bonny.CRD

  describe "to_manifest/2" do
    test "generates a kubernetes manifest in version v1beta1" do
      spec = Widget.crd()
      manifest = CRD.to_manifest(spec, "apiextensions.k8s.io/v1beta1")

      expected = %{
        apiVersion: "apiextensions.k8s.io/v1beta1",
        kind: "CustomResourceDefinition",
        metadata: %{
          name: "widgets.example.com",
          labels: %{"k8s-app" => "bonny"}
        },
        spec: %{
          group: "example.com",
          names: %{kind: "Widget", plural: "widgets", shortNames: nil, singular: "widget"},
          scope: "Namespaced",
          version: "v1",
          additionalPrinterColumns: [
            %{JSONPath: ".spec.test", description: "test", name: "test", type: "string"},
            %{
              JSONPath: ".metadata.creationTimestamp",
              description:
                "CreationTimestamp is a timestamp representing the server time when this object was created. It is not guaranteed to be set in happens-before order across separate operations. Clients may not set this value. It is represented in RFC3339 form and is in UTC.\n\n      Populated by the system. Read-only. Null for lists. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata",
              name: "Age",
              type: "date"
            }
          ]
        }
      }

      assert expected == manifest
    end

    test "generates a kubernetes manifest in version v1" do
      spec = Widget.crd()
      manifest = CRD.to_manifest(spec, "apiextensions.k8s.io/v1")

      expected = %{
        apiVersion: "apiextensions.k8s.io/v1",
        kind: "CustomResourceDefinition",
        metadata: %{
          name: "widgets.example.com",
          labels: %{"k8s-app" => "bonny"}
        },
        spec: %{
          group: "example.com",
          names: %{kind: "Widget", plural: "widgets", shortNames: nil, singular: "widget"},
          scope: "Namespaced",
          versions: [
            %{
              name: "v1",
              served: true,
              storage: true,
              schema: %{
                openAPIV3Schema: %{
                  type: "object",
                  "x-kubernetes-preserve-unknown-fields": true
                }
              },
              additionalPrinterColumns: [
                %{jsonPath: ".spec.test", description: "test", name: "test", type: "string"},
                %{
                  jsonPath: ".metadata.creationTimestamp",
                  description:
                    "CreationTimestamp is a timestamp representing the server time when this object was created. It is not guaranteed to be set in happens-before order across separate operations. Clients may not set this value. It is represented in RFC3339 form and is in UTC.\n\n      Populated by the system. Read-only. Null for lists. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata",
                  name: "Age",
                  type: "date"
                }
              ]
            }
          ]
        }
      }

      assert expected == manifest
    end
  end
end
