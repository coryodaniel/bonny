defmodule Bonny.Pluggable.Finalizer do
  @moduledoc """
  Declare a finalizer and its implementation.

  ### Kubernetes Docs:

  * https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/
  * https://kubernetes.io/blog/2021/05/14/using-finalizers-to-control-deletion/

  > #### Use with `SkipObservedGenerations` {: .tip}
  >
  > This step is best used with and placed right after
  > `Bonny.Pluggable.SkipObservedGenerations` in your controller. Have a look at
  > the examples below.

  > #### Note for Testing {: .warning}
  >
  > This step directly updates the resource on the kubernetes
  > cluster. In order to write unit tests, you therefore want to use
  > `K8s.Client.DynamicHTTPProvider` in order to mock the calls to Kubernetes.

  ### Examples

  See `t:options/0`, `t:finalizer_impl/0` and `t:add_to_resource/0` for more
  infos on the options.

  By default, a missing finalizer is not added to the resource.

      step Bonny.Pluggable.SkipObservedGenerations
      step Bonny.Pluggable.Finalizer,
        id: "example.com/cleanup",
        impl: &__MODULE__.cleanup/1

  Set `add_to_resource` to true in order for Bonny to always add it.

      step Bonny.Pluggable.SkipObservedGenerations
      step Bonny.Pluggable.Finalizer,
        id: "example.com/cleanup",
        impl: &__MODULE__.cleanup/1,
        add_to_resource: true

  Or make it depending on the event/resource and enable logs.

      step Bonny.Pluggable.SkipObservedGenerations
      step Bonny.Pluggable.Finalizer,
        id: "example.com/cleanup",
        impl: &__MODULE__.cleanup/1,
        add_to_resource: &__MODULE__.deletion_policy_not_abandon/1,
        log: :debug

  """

  @behaviour Pluggable

  import YamlElixir.Sigil

  require Logger

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
  - `log_level` - (optional) Log level used for logging by this step. `:disable` for no
    logs. Defaults to `:disable`
  """
  @type options :: [
          {:id, binary()}
          | {:impl, finalizer_impl()}
          | {:add_to_resource, add_to_resource()}
          | {:log_level, Logger.level() | :disable}
        ]
  @typep finalizer :: %{
           id: binary(),
           impl: finalizer_impl(),
           add: add_to_resource(),
           log_level: Logger.level() | :disable
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
      add: Keyword.get(opts, :add_to_resource, false),
      log_level: Keyword.get(opts, :log_level, :disable)
    }
  end

  @impl true
  @spec call(Bonny.Axn.t(), finalizer()) :: Bonny.Axn.t()
  def call(%Bonny.Axn{resource: %{"metadata" => metadata}} = axn, finalizer)
      when is_map_key(metadata, "deletionTimestamp") and axn.action in [:modify, :reconcile] do
    %{id: finalizer_id, impl: finalizer_impl, log_level: log_level} = finalizer

    if finalizer_id in Map.get(metadata, "finalizers", []) do
      log(
        log_level,
        ~s(#{inspect(Bonny.Axn.identifier(axn))} - Calling finalizer implementation for finalizer "#{finalizer_id}")
      )

      case finalizer_impl.(axn) do
        {:ok, axn} ->
          log(
            log_level,
            ~s(#{inspect(Bonny.Axn.identifier(axn))} - Removing finalizer "#{finalizer_id}" from resource metadata)
          )

          new_finalizers_list = List.delete(axn.resource["metadata"]["finalizers"], finalizer_id)
          patch_finalizers(axn, new_finalizers_list)
          Pluggable.Token.halt(axn)

        {:error, axn} ->
          Pluggable.Token.halt(axn)
      end
    else
      axn
    end
  end

  def call(%Bonny.Axn{resource: %{"metadata" => metadata}, action: action} = axn, finalizer)
      when not is_map_key(metadata, "deletionTimestamp") and action != :delete do
    %{id: finalizer_id, log_level: log_level} = finalizer

    Bonny.Axn.register_after_processed(axn, fn axn ->
      list_of_finalizers = List.wrap(axn.resource["metadata"]["finalizers"])
      finalizer_present? = finalizer_id in list_of_finalizers
      add_to_resource? = add_to_resource?(axn, finalizer)

      cond do
        add_to_resource? and not finalizer_present? ->
          new_finalizers_list = [finalizer_id | list_of_finalizers]
          axn = put_in(axn.resource["metadata"]["finalizers"], new_finalizers_list)

          log(
            log_level,
            ~s(#{inspect(Bonny.Axn.identifier(axn))} - Adding finalizer "#{finalizer_id}" to resource metadata)
          )

          patch_finalizers(axn, axn.resource["metadata"]["finalizers"])

        finalizer_present? and not add_to_resource? ->
          new_finalizers_list = List.delete(list_of_finalizers, finalizer_id)
          axn = put_in(axn.resource["metadata"]["finalizers"], new_finalizers_list)

          log(
            log_level,
            ~s(#{inspect(Bonny.Axn.identifier(axn))} - Removing finalizer "#{finalizer_id}" to resource metadata)
          )

          patch_finalizers(axn, axn.resource["metadata"]["finalizers"])

        :otherwise ->
          axn
      end
    end)
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

  @spec log(Logger.level() | :disable, Logger.message()) :: :ok
  defp log(:disable, _message), do: :ok
  defp log(log_level, message), do: Logger.log(log_level, message)
end
