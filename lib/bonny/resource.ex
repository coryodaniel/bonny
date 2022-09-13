defmodule Bonny.Resource do
  @moduledoc """
  Helper functions for dealing with kubernetes resources.
  """

  @type t :: map()

  @doc """
  Add an owner reference to the given resource.

  ### Example

      iex> owner = %{
      ...>   "apiVersion" => "example.com/v1",
      ...>   "kind" => "Orange",
      ...>   "metadata" => %{
      ...>     "name" => "annoying",
      ...>     "namespace" => "default",
      ...>     "uid" => "e19b6f40-3293-11ed-a261-0242ac120002"
      ...>   }
      ...> }
      ...> resource = %{
      ...>   "apiVersion" => "v1",
      ...>   "kind" => "Pod",
      ...>   "metadata" => %{"name" => "nginx", "namespace" => "default"}
      ...>   # spec
      ...> }
      ...> Bonny.Resource.add_owner_reference(resource, owner)
      %{
        "apiVersion" => "v1",
        "kind" => "Pod",
        "metadata" => %{
          "name" => "nginx",
          "namespace" => "default",
          "ownerReferences" => [%{
            "apiVersion" => "example.com/v1",
            "blockOwnerDeletion" => false,
            "controller" => true,
            "kind" => "Orange",
            "name" => "annoying",
            "uid" => "e19b6f40-3293-11ed-a261-0242ac120002"
          }]
        }
      }
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
