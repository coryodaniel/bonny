defmodule Bonny.ResourceTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Bonny.Resource, as: MUT

  describe "add_owner_reference/3" do
    setup do
      resource = %{
        "apiVersion" => "example.com/v1",
        "kind" => "Cog",
        "metadata" => %{
          "name" => "some-cog",
          "namespace" => "default"
        }
      }

      resource_with_atoms = %{
        apiVersion: "example.com/v1",
        kind: "Cog",
        metadata: %{
          name: "some-cog",
          namespace: "default"
        }
      }

      owner = %{
        "apiVersion" => "example.com/v1",
        "kind" => "Widget",
        "metadata" => %{
          "name" => "some-widget",
          "namespace" => "default",
          "uid" => "d9607e19-f88f-11e6-a518-42010a800195"
        }
      }

      [resource: resource, resource_with_atoms: resource_with_atoms, owner: owner]
    end

    test "adds the reference", %{resource: resource, owner: owner} do
      resource_with_ownerref = MUT.add_owner_reference(resource, owner)

      assert hd(resource_with_ownerref["metadata"]["ownerReferences"]) == %{
               "apiVersion" => "example.com/v1",
               "kind" => "Widget",
               "blockOwnerDeletion" => false,
               "controller" => true,
               "name" => "some-widget",
               "uid" => "d9607e19-f88f-11e6-a518-42010a800195"
             }
    end

    test "adds the reference to list of existing references", %{resource: resource, owner: owner} do
      resource_with_ownerref =
        resource
        |> put_in(["metadata", "ownerReferences"], [
          %{"name" => "existing-ref", "uid" => "foobar"}
        ])
        |> MUT.add_owner_reference(owner)

      assert length(resource_with_ownerref["metadata"]["ownerReferences"]) == 2
    end

    test "adds the reference for resource with atoms", %{
      resource_with_atoms: resource,
      owner: owner
    } do
      resource_with_ownerref = MUT.add_owner_reference(resource, owner)

      assert hd(resource_with_ownerref[:metadata][:ownerReferences]) == %{
               "apiVersion" => "example.com/v1",
               "kind" => "Widget",
               "blockOwnerDeletion" => false,
               "controller" => true,
               "name" => "some-widget",
               "uid" => "d9607e19-f88f-11e6-a518-42010a800195"
             }
    end

    test "sets blockOnwerDeletion", %{resource: resource, owner: owner} do
      resource_with_ownerref =
        MUT.add_owner_reference(resource, owner, block_owner_deletion: true)

      assert resource_with_ownerref
             |> get_in(["metadata", "ownerReferences"])
             |> hd()
             |> Map.get("blockOwnerDeletion") == true
    end
  end
end
