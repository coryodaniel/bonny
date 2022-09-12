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
  @spec add_owner_reference(t(), map(), keyword(boolean)) :: t()
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

  @doc """
  Sets .status.observedGeneration to .metadata.generation
  """
  @spec set_observed_generation(t()) :: t()
  def set_observed_generation(resource) do
    generation = get_in(resource, ~w(metadata generation))
    put_in(resource, [Access.key("status", %{}), "observedGeneration"], generation)
  end

  @doc """
  Removes .metadata.managedFields from the resource.
  """
  @spec drop_managed_fields(t()) :: t()
  def drop_managed_fields(resource),
    do: Map.update!(resource, "metadata", &Map.delete(&1, "managedFields"))

  @doc """
  Applies the status subresource of the given resource. Requires to pass the
  plural form of the resource kind.
  If the given resource doesn't contain a status object, nothing is done and
  :noop is returned.
  """
  @spec apply_status(t(), binary(), K8s.Conn.t()) :: K8s.Client.Runner.Base.result_t() | :noop
  def apply_status(resource, plural_resource_kind, conn)
      when is_map_key(resource, "status") or is_map_key(resource, :status) do
    op =
      K8s.Client.apply(
        resource["apiVersion"],
        plural_resource_kind <> "/status",
        [
          namespace: get_in(resource, ~w(metadata namespace)),
          name: get_in(resource, ~w(metadata name))
        ],
        drop_managed_fields(resource),
        field_manager: Bonny.Config.name(),
        force: true
      )

    K8s.Client.run(conn, op)
  end

  def apply_status(_, _, _), do: :noop
end
