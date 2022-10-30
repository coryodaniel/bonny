defmodule Bonny.Resource do
  @moduledoc """
  Helper functions for dealing with kubernetes resources.
  """

  @type t :: map()

  @doc """
  Get a reference to the given resource

  ### Example

      iex> resource = %{
      ...>   "apiVersion" => "example.com/v1",
      ...>   "kind" => "Orange",
      ...>   "metadata" => %{
      ...>     "name" => "annoying",
      ...>     "namespace" => "default",
      ...>     "uid" => "e19b6f40-3293-11ed-a261-0242ac120002"
      ...>   }
      ...> }
      ...> Bonny.Resource.resource_reference(resource)
      %{
        "apiVersion" => "example.com/v1",
        "kind" => "Orange",
        "name" => "annoying",
        "namespace" => "default",
        "uid" => "e19b6f40-3293-11ed-a261-0242ac120002"
      }
  """
  def resource_reference(nil), do: nil

  def resource_reference(resource) do
    ref = %{
      "apiVersion" => K8s.Resource.FieldAccessors.api_version(resource),
      "kind" => K8s.Resource.FieldAccessors.kind(resource),
      "name" => K8s.Resource.FieldAccessors.name(resource),
      "uid" => get_in(resource, ~w(metadata uid))
    }

    namespace = get_in(resource, ~w(metadata namespace))
    if is_nil(namespace), do: ref, else: Map.put(ref, "namespace", namespace)
  end

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
            "namespace" => "default",
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
    resource
    |> resource_reference()
    |> Map.put("blockOwnerDeletion", Keyword.get(opts, :block_owner_deletion, false))
    |> Map.put("controller", true)
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
  Applies the given resource to the cluster.
  """
  @spec apply(t(), K8s.Conn.t(), Keyword.t()) :: K8s.Client.Runner.Base.result_t()
  def apply(resource, conn, opts) do
    opts =
      Keyword.merge([force: true], opts)
      |> Keyword.put_new_lazy(:field_manager, fn -> Bonny.Config.name() end)

    op = K8s.Client.apply(resource, opts)
    K8s.Client.run(conn, op)
  end

  @doc """
  Applies the given resource to the cluster.
  """
  @spec apply_async(list(t()), K8s.Conn.t(), Keyword.t()) ::
          list({t(), K8s.Client.Runner.Base.result_t()})
  def apply_async(resources, conn, opts \\ []) do
    opts =
      Keyword.merge([force: true], opts)
      |> Keyword.put_new_lazy(:field_manager, fn -> Bonny.Config.name() end)

    ops = Enum.map(resources, &K8s.Client.apply(&1, opts))
    results = K8s.Client.async(conn, ops)
    Enum.zip(resources, results)
  end

  @doc """
  Applies the status subresource of the given resource to the cluster.
  If the given resource doesn't contain a status object, nothing is done and
  :noop is returned.
  """
  @spec apply_status(t(), K8s.Conn.t(), Keyword.t()) :: K8s.Client.Runner.Base.result_t() | :noop
  def apply_status(resource, conn, opts \\ [])

  def apply_status(resource, conn, opts)
      when is_map_key(resource, "status") or is_map_key(resource, :status) do
    opts =
      Keyword.merge([force: true], opts)
      |> Keyword.put_new_lazy(:field_manager, fn -> Bonny.Config.name() end)

    op =
      K8s.Client.apply(
        resource["apiVersion"],
        {resource["kind"], "Status"},
        [
          namespace: get_in(resource, ~w(metadata namespace)),
          name: get_in(resource, ~w(metadata name))
        ],
        drop_managed_fields(resource),
        opts
      )

    K8s.Client.run(conn, op)
  end

  def apply_status(_, _, _), do: :noop

  @doc """
  Returns a tuple in the form

  * {apiVersion, kind, namespace/name} for namespaced resources
  * {apiVersion, kind, name} for cluster scoped resources
  """
  @spec gvkn(t()) :: {binary(), binary(), binary()}
  def gvkn(resource) do
    ns_name =
      String.trim_leading(
        "#{resource["metadata"]["namespace"]}/#{resource["metadata"]["name"]}",
        "/"
      )

    {ns_name, resource["apiVersion"], "Kind=#{resource["kind"]}"}
  end
end
