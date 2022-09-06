defmodule Bonny.Resource do
  @moduledoc """
  Helper functions for dealing with kubernetes resources.
  """

  @doc """
  Add an owner reference to the given resource.
  """
  @spec add_owner_reference(map(), map(), keyword(boolean)) :: map()
  def add_owner_reference(resource, owner, opts \\ [])

  def add_owner_reference(%{"metadata" => _} = resource, owner, opts) do
    owner_ref = owner_reference(owner, opts)

    put_in(
      resource,
      [
        "metadata",
        Access.key("ownerReferences", []),
        K8s.Resource.NamedList.access(owner_ref["name"])
      ],
      owner_ref
    )
  end

  def add_owner_reference(%{metadata: _} = resource, owner, opts) do
    owner_ref = owner_reference(owner, opts)

    put_in(
      resource,
      [
        :metadata,
        Access.key(:ownerReferences, []),
        K8s.Resource.NamedList.access(owner_ref["name"])
      ],
      owner_ref
    )
  end

  defp owner_reference(resource, opts) do
    %{
      "apiVersion" => get_in(resource, ["apiVersion"]),
      "kind" => get_in(resource, ["kind"]),
      "name" => get_in(resource, ["metadata", "name"]),
      "uid" => get_in(resource, ["metadata", "uid"]),
      "blockOwnerDeletion" => Keyword.get(opts, :block_owner_deletion, false),
      "controller" => true
    }
  end
end
