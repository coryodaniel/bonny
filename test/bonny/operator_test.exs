defmodule Bonny.OperatorTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Operator

  test "cluster_role/0" do
    manifest = Operator.cluster_role()

    expected = %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRole",
      metadata: %{labels: %{"k8s-app" => "bonny"}, name: "bonny"},
      rules: [
        %{
          apiGroups: ["apiextensions.k8s.io"],
          resources: ["customresourcedefinitions"],
          verbs: ["*"]
        },
        %{apiGroups: ["events.k8s.io/v1"], resources: ["events"], verbs: ["*"]},
        %{
          apiGroups: ["example.com"],
          resources: ["widgets"],
          verbs: ["*"]
        },
        %{
          apiGroups: ["example.com"],
          resources: ["cogs"],
          verbs: ["*"]
        },
        %{
          apiGroups: ["example.com"],
          resources: ["whizbangs"],
          verbs: ["*"]
        },
        %{
          apiGroups: ["example.com"],
          resources: ["testresources"],
          verbs: ["*"]
        },
        %{
          apiGroups: ["example.com"],
          resources: ["testresourcev2s"],
          verbs: ["*"]
        },
        %{
          apiGroups: ["example.com"],
          resources: ["testresourcev3s"],
          verbs: ["*"]
        },
        %{apiGroups: ["apps"], resources: ["deployments", "services"], verbs: ["*"]},
        %{apiGroups: [""], resources: ["configmaps"], verbs: ["create", "read"]},
        %{apiGroups: ["example.com"], resources: ["testresourcev2s/status"], verbs: ["*"]},
        %{apiGroups: [""], resources: ["secrets"], verbs: ["get", "watch", "list"]}
      ]
    }

    assert manifest == expected
  end

  test "rules/0" do
    manifest = Operator.rules()

    expected = [
      %{
        apiGroups: ["apiextensions.k8s.io"],
        resources: ["customresourcedefinitions"],
        verbs: ["*"]
      },
      %{apiGroups: ["events.k8s.io/v1"], resources: ["events"], verbs: ["*"]},
      %{
        apiGroups: ["example.com"],
        resources: ["widgets"],
        verbs: ["*"]
      },
      %{
        apiGroups: ["example.com"],
        resources: ["cogs"],
        verbs: ["*"]
      },
      %{
        apiGroups: ["example.com"],
        resources: ["whizbangs"],
        verbs: ["*"]
      },
      %{
        apiGroups: ["example.com"],
        resources: ["testresources"],
        verbs: ["*"]
      },
      %{
        apiGroups: ["example.com"],
        resources: ["testresourcev2s"],
        verbs: ["*"]
      },
      %{
        apiGroups: ["example.com"],
        resources: ["testresourcev3s"],
        verbs: ["*"]
      },
      %{apiGroups: ["apps"], resources: ["deployments", "services"], verbs: ["*"]},
      %{apiGroups: [""], resources: ["configmaps"], verbs: ["create", "read"]},
      %{apiGroups: ["example.com"], resources: ["testresourcev2s/status"], verbs: ["*"]},
      %{apiGroups: [""], resources: ["secrets"], verbs: ["get", "watch", "list"]}
    ]

    assert manifest == expected
  end

  test "service_account/1" do
    manifest = Operator.service_account("default")

    expected = %{
      metadata: %{name: "bonny", labels: %{"k8s-app" => "bonny"}, namespace: "default"},
      apiVersion: "v1",
      kind: "ServiceAccount"
    }

    assert manifest == expected
  end

  test "crds/0" do
    manifest = Operator.crds()

    assert [
             %{
               apiVersion: "apiextensions.k8s.io/v1",
               kind: "CustomResourceDefinition",
               metadata: %{labels: %{"k8s-app" => "bonny"}, name: "widgets.example.com"},
               spec: %{
                 group: "example.com",
                 names: %{kind: "Widget", plural: "widgets", shortNames: nil, singular: "widget"},
                 scope: "Namespaced",
                 versions: [
                   %{
                     additionalPrinterColumns: [
                       %{
                         description: "test",
                         jsonPath: ".spec.test",
                         name: "test",
                         type: "string"
                       },
                       %{
                         description:
                           "CreationTimestamp is a timestamp representing the server time when this object was created. It is not guaranteed to be set in happens-before order across separate operations. Clients may not set this value. It is represented in RFC3339 form and is in UTC.\n\n      Populated by the system. Read-only. Null for lists. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata",
                         jsonPath: ".metadata.creationTimestamp",
                         name: "Age",
                         type: "date"
                       }
                     ],
                     name: "v1",
                     schema: %{
                       openAPIV3Schema: %{
                         type: "object",
                         "x-kubernetes-preserve-unknown-fields": true
                       }
                     },
                     served: true,
                     storage: true
                   }
                 ]
               }
             },
             %{
               apiVersion: "apiextensions.k8s.io/v1",
               kind: "CustomResourceDefinition",
               metadata: %{labels: %{"k8s-app" => "bonny"}, name: "cogs.example.com"},
               spec: %{
                 group: "example.com",
                 names: %{kind: "Cog", plural: "cogs", shortNames: nil, singular: "cog"},
                 scope: "Namespaced",
                 versions: [
                   %{
                     additionalPrinterColumns: [],
                     name: "v1",
                     schema: %{
                       openAPIV3Schema: %{
                         type: "object",
                         "x-kubernetes-preserve-unknown-fields": true
                       }
                     },
                     served: true,
                     storage: true
                   }
                 ]
               }
             },
             %{
               apiVersion: "apiextensions.k8s.io/v1",
               kind: "CustomResourceDefinition",
               metadata: %{labels: %{"k8s-app" => "bonny"}, name: "whizbangs.example.com"},
               spec: %{
                 group: "example.com",
                 names: %{
                   kind: "Whizbang",
                   plural: "whizbangs",
                   shortNames: nil,
                   singular: "whizbang"
                 },
                 scope: "Namespaced",
                 versions: [
                   %{
                     additionalPrinterColumns: [],
                     name: "v1",
                     schema: %{
                       openAPIV3Schema: %{
                         type: "object",
                         "x-kubernetes-preserve-unknown-fields": true
                       }
                     },
                     served: true,
                     storage: true
                   }
                 ]
               }
             },
             %{
               apiVersion: "apiextensions.k8s.io/v1",
               kind: "CustomResourceDefinition",
               metadata: %{labels: %{"k8s-app" => "bonny"}, name: "testresources.example.com"},
               spec: %{
                 group: "example.com",
                 names: %{
                   kind: "TestResource",
                   plural: "testresources",
                   shortNames: nil,
                   singular: "testresource"
                 },
                 scope: "Namespaced",
                 versions: [
                   %{
                     additionalPrinterColumns: [],
                     name: "v1",
                     schema: %{
                       openAPIV3Schema: %{
                         type: "object",
                         "x-kubernetes-preserve-unknown-fields": true
                       }
                     },
                     served: true,
                     storage: true
                   }
                 ]
               }
             },
             %{
               apiVersion: "apiextensions.k8s.io/v1",
               kind: "CustomResourceDefinition",
               metadata: %{labels: %{"k8s-app" => "bonny"}, name: "testresourcev2s.example.com"},
               spec: %{
                 group: "example.com",
                 names: %{
                   kind: "TestResourceV2",
                   plural: "testresourcev2s",
                   shortNames: [],
                   singular: "testresourcev2"
                 },
                 scope: :Namespaced,
                 versions: [
                   %Bonny.API.Version{
                     name: "v1",
                     served: true,
                     storage: true,
                     deprecated: false,
                     deprecationWarning: nil,
                     schema: %{
                       openAPIV3Schema: %{
                         type: :object,
                         properties: %{
                           spec: %{
                             properties: %{pid: %{type: :string}, ref: %{type: :string}},
                             type: :object
                           }
                         }
                       }
                     },
                     additionalPrinterColumns: []
                   }
                 ]
               }
             }
             | _
           ] = manifest
  end

  test "cluster_role_binding/1" do
    manifest = Operator.cluster_role_binding("default")

    expected = %{
      apiVersion: "rbac.authorization.k8s.io/v1",
      kind: "ClusterRoleBinding",
      metadata: %{name: "bonny", labels: %{"k8s-app" => "bonny"}},
      roleRef: %{apiGroup: "rbac.authorization.k8s.io", kind: "ClusterRole", name: "bonny"},
      subjects: [%{kind: "ServiceAccount", name: "bonny", namespace: "default"}]
    }

    assert manifest == expected
  end
end
