defmodule Bonny.Pluggable.Finalizer do
  @moduledoc """
  Declare a finalizer and its implementation.

  ### Kubernetes Docs:

  * https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/
  * https://kubernetes.io/blog/2021/05/14/using-finalizers-to-control-deletion/

  > Note for Testing: This step directly updates the resource on the kubernetes
  > cluster. In order to write unit tests, you therefore want to use
  > `K8s.Client.DynamicHTTPProvider` in order to mock the calls to Kubernetes

  ### Examples

  See `t:options/0`, `t:finalizer_impl/0` and `t:add_to_resource/0` for more
  infos on the options.

  By default, a missing finalizer is not added to the resource.

      step Bonny.Pluggable.Finalizer,
        id: "example.com/cleanup",
        impl: &__MODULE__.cleanup/1

  Set `add_to_resource` to true in order for Bonny to always add it.

      step Bonny.Pluggable.Finalizer,
        id: "example.com/cleanup",
        impl: &__MODULE__.cleanup/1,
        add_to_resource: true

  Or make it depending on the event/resource.

      step Bonny.Pluggable.Finalizer,
        id: "example.com/cleanup",
        impl: &__MODULE__.cleanup/1,
        add_to_resource: &__MODULE__.deletion_policy_not_abandon/1

  """

  @behaviour Pluggable

  import YamlElixir.Sigil

  @typedoc """
  The implementation of the finalizer. This is a function of arity 1 which is
  called when the resource is deleted. It receives the `%Bonny.Axn{}` token as
  argument and should return the same.
  """
  @type finalizer_impl :: (Bonny.Axn.t() -> {:ok, Bonny.Axn.t()} | {:error, Bonny.Axn.t()})

  @typedoc """
  Boolean or callback of arity 1 to tell Bonny whether or not to add the
  finalizer to the resource if it is missing. If it is a callback, it receives
  the `%Bonny.Axn{}` token and shoulr return a `boolean`.
  """
  @type add_to_resource :: boolean() | (Bonny.Axn.t() -> boolean())

  @typedoc """
  - `id` - Fully qualified finalizer identifier
  - `impl` - The implementation of the finalizer. See `t:finalizer_impl/0`
  - `add_to_resource` - (otional) whether Bonny should add the finalizer to the
    resource if it is missing. See `t:add_to_resource/0`
    `%Bonny.Axn{}` token. Defaults to `false`.
  """
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
    id = Keyword.fetch!(opts, :id)

    if !String.contains?(id, "/") do
      raise "The finalizer identifier #{inspect(id)} is not fully qualified. It has to be in form \"domain/name\"."
    end

    %{
      id: id,
      impl: Keyword.fetch!(opts, :impl),
      add: Keyword.get(opts, :add_to_resource, false)
    }
  end

  @impl true
  @spec call(Bonny.Axn.t(), finalizer()) :: Bonny.Axn.t()
  def call(%Bonny.Axn{resource: %{"metadata" => metadata}} = axn, finalizer)
      when is_map_key(metadata, "deletionTimestamp") and axn.action == :modify do
    if finalizer.id in Map.get(metadata, "finalizers", []) do
      case finalizer.impl.(axn) do
        {:ok, axn} ->
          new_finalizers_list = List.delete(axn.resource["metadata"]["finalizers"], finalizer.id)
          patch_finalizers(axn, new_finalizers_list)
          Pluggable.Token.halt(axn)

        {:error, axn} ->
          Pluggable.Token.halt(axn)
      end
    else
      axn
    end
  end

  def call(%Bonny.Axn{resource: %{"metadata" => metadata}} = axn, finalizer)
      when not is_map_key(metadata, "deletionTimestamp") do
    if add_to_resource?(axn, finalizer) and
         finalizer.id not in Map.get(metadata, "finalizers", []) do
      new_finalizers_list = [finalizer.id | Map.get(metadata, "finalizers", [])]
      axn = put_in(axn.resource["metadata"]["finalizers"], new_finalizers_list)

      Bonny.Axn.register_after_processed(axn, fn axn ->
        patch_finalizers(axn, axn.resource["metadata"]["finalizers"])
      end)
    else
      axn
    end
  end

  def call(axn, _finalizer) do
    axn
  end

  @spec add_to_resource?(Bonny.Axn.t(), finalizer()) :: boolean()
  defp add_to_resource?(_axn, %{add: add}) when is_boolean(add), do: add
  defp add_to_resource?(axn, %{add: add}) when is_function(add), do: add.(axn)

  defp patch_finalizers(%Bonny.Axn{resource: resource, conn: conn}, finalizers) do
    patch =
      ~y"""
      apiVersion: #{resource["apiVersion"]}
      kind: #{resource["kind"]}
      metadata:
        name: #{resource["metadata"]["name"]}
        namespace: #{resource["metadata"]["namespace"]}

      """
      |> put_in(~w(metadata finalizers), finalizers)

    patch
    |> K8s.Client.patch()
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()
  end
end
