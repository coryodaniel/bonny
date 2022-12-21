# credo:disable-for-this-file
defmodule Bonny.ResourceTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Bonny.Resource, as: MUT

  doctest MUT

  defmodule K8sMock do
    require Logger

    import K8s.Client.HTTPTestHelper

    def conn(), do: Bonny.K8sMock.conn(__MODULE__)

    def request(
          :patch,
          %URI{path: "apis/example.com/v1/namespaces/default/widgets/foo/status"},
          body,
          _headers,
          _opts
        ) do
      ref =
        body
        |> Jason.decode!()
        |> get_in(~w(status ref))
        |> String.to_charlist()
        |> :erlang.list_to_ref()

      send(self(), {ref, "status applied"})

      render(%{})
    end

    def request(_method, _uri, _body, _headers, _opts) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %K8s.Client.HTTPError{message: "request not mocked"}}
    end
  end

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

  describe "set_observed_generation/1" do
    test "sets .status.observedGeneration to whatever is in .metadata.generation" do
      res = MUT.set_observed_generation(%{"metadata" => %{"generation" => "some-value"}})

      assert res["status"]["observedGeneration"] == "some-value"
    end

    test "does not modify or remove other status values" do
      res =
        MUT.set_observed_generation(%{
          "metadata" => %{"generation" => "some-value"},
          "status" => %{"preserved" => "field"}
        })

      assert res["status"]["preserved"] == "field"
    end
  end

  describe "drop_managed_fields/1" do
    test "drop .metadata.managedFields when present" do
      res = MUT.drop_managed_fields(%{"metadata" => %{"managedFields" => "present"}})

      refute Map.has_key?(res["metadata"], "managedFields")
    end

    test "noop if no such fields" do
      res = %{"metadata" => %{"other" => "field"}}
      updated_res = MUT.drop_managed_fields(res)

      assert res == updated_res
    end
  end

  describe "apply_status/3" do
    setup do
      conn = __MODULE__.K8sMock.conn()
      ref = make_ref()

      resource = %{
        "apiVersion" => "example.com/v1",
        "kind" => "Widget",
        "metadata" => %{
          "name" => "foo",
          "namespace" => "default"
        }
      }

      [conn: conn, ref: ref, resource: resource]
    end

    test "calls k8s library to apply status when present", %{
      conn: conn,
      ref: ref,
      resource: resource
    } do
      resource =
        Map.put(resource, "status", %{
          "some" => "field",
          "ref" => ref |> :erlang.ref_to_list() |> List.to_string()
        })

      assert {:ok, _} = MUT.apply_status(resource, conn)
      assert_receive {^ref, "status applied"}
    end

    test "noop if no status in resource", %{
      conn: conn,
      resource: resource
    } do
      assert :noop == MUT.apply_status(resource, conn)
    end
  end
end
