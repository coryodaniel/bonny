defmodule Bonny.Pluggable.Finalizer do
  @behaviour Pluggable

  @type finalizer_impl :: (Bonny.Axn.t() -> {:ok, Bonny.Axn.t()} | {:error, Bonny.Axn.t()})
  @type add_to_resource :: boolean() | (Bonny.Axn.t() -> boolean())
  @type options :: [
          {:id, binary()} | {:impl, finalizer_impl()} | {:add_to_resource, add_to_resource()}
        ]
  @typep finalizer :: %{
           id: binary(),
           impl: finalizer_impl(),
           add: add_to_resource()
         }

  @impl true
  @spec init(options()) :: finalizer()
  def init(opts) do
    %{
      id: Keyword.fetch!(opts, :id),
      impl: Keyword.fetch!(opts, :impl),
      add: Keyword.get(opts, :add_to_resource, false)
    }
  end

  @impl true
  @spec call(Bonny.Axn.t(), finalizer()) :: Bonny.Axn.t()
  def call(%Bonny.Axn{resource: %{"metadata" => metadata}} = axn, finalizer)
      when is_map_key(metadata, "deletionTimestamp") do
    if finalizer.id in Map.get(metadata, "finalizers", []) do
      case finalizer.impl.(axn) do
        {:ok, axn} ->
          {:ok, resource} =
            axn.resource
            |> update_in(~w(metadata finalizers), &List.delete(&1, finalizer.id))
            |> Bonny.Resource.drop_managed_fields()
            |> K8s.Client.apply()
            |> K8s.Client.put_conn(axn.conn)
            |> K8s.Client.run()

          axn
          |> struct!(resource: resource)
          |> Pluggable.Token.halt()

        {:error, axn} ->
          Pluggable.Token.halt(axn)
      end
    else
      Pluggable.Token.halt(axn)
    end
  end

  def call(%Bonny.Axn{resource: %{"metadata" => metadata}} = axn, finalizer) do
    if add_to_resource?(axn, finalizer) and
         finalizer.id not in Map.get(metadata, "finalizers", []) do
      axn =
        update_in(
          axn,
          [Access.key(:resource), "metadata", Access.key("finalizers", [])],
          &(&1 ++ [finalizer.id])
        )

      Bonny.Axn.register_descendant(axn, axn.resource, omit_owner_ref: true)
    else
      axn
    end
  end

  @spec add_to_resource?(Bonny.Axn.t(), finalizer()) :: boolean()
  defp add_to_resource?(_axn, %{add: add}) when is_boolean(add), do: add
  defp add_to_resource?(axn, %{add: add}) when is_function(add), do: add.(axn)
end
