defmodule Bonny.Pluggable.AddFinalizer do
  @behaviour Pluggable

  @type finalizer_impl :: (Bonny.Axn.t() -> {:ok, Bonny.Axn.t()} | {:error, Bonny.Axn.t()})
  @type skip_if :: (Bonny.Axn.t() -> boolean())
  @type options :: [{:id, binary()} | {:impl, finalizer_impl()} | {:skip_if, skip_if()}]

  @impl true
  def init(opts) do
    %{
      id: Keyword.fetch!(opts, :id),
      impl: Keyword.fetch!(opts, :impl),
      skip_if: Keyword.get(opts, :skip_if, fn _ -> false end)
    }
  end

  @impl true
  @spec call(Bonny.Axn.t(), %{id: binary(), impl: finalizer_impl(), skip_if: skip_if()}) ::
          Bonny.Axn.t()
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
    if finalizer.id in Map.get(metadata, "finalizers", []) or finalizer.skip_if.(axn) do
      axn
    else
      resource_with_finalizer =
        update_in(
          axn.resource,
          ["metadata", Access.key("finalizers", [])],
          &(&1 ++ [finalizer.id])
        )

      Bonny.Axn.register_descendant(axn, resource_with_finalizer, omit_owner_ref: true)
    end
  end
end
