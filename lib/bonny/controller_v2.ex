defmodule Bonny.ControllerV2 do
  @moduledoc """
  `Bonny.ControllerV2` defines controller behaviours and generates boilerplate
  for generating Kubernetes manifests.

  > A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

  Controllers allow for simple `add`, `modify`, `delete`, and `reconcile`
  handling of custom resources in the Kubernetes API.

  This version of the controller lets you customize the resulting CRD before
  you generate your manifest using `mix bonny.gen.manifest`.
  """

  alias Bonny.CRDV2, as: CRD

  @doc """
  Should return an operation to list resources for watching and reconciliation.

  Bonny.ControllerV2 comes with a default implementation which can be
  overridden by the using module.
  """
  @callback list_operation() :: K8s.Operation.t()

  @doc """
  Bonny.ControllerV2 comes with a default implementation which returns Bonny.Config.config()
  """
  @callback conn() :: K8s.Conn.t()

  @doc """
  Bonny auto-generates a CRD for every controller. Use this (optional) callback to
  override that CRD. You can use it to add versions, specify the OpenAPIV3Schema for them,
  change the resource's scope, and more.
  """
  @callback customize_crd(Bonny.CRDV2.t()) :: Bonny.CRDV2.t()

  #  Action Callbacks
  @callback add(map()) :: :ok | :error
  @callback modify(map()) :: :ok | :error
  @callback delete(map()) :: :ok | :error
  @callback reconcile(map()) :: :ok | :error

  @optional_callbacks customize_crd: 1

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      rules =
        opts
        |> Keyword.get_lazy(:rbac_rules, fn -> Keyword.get_values(opts, :rbac_rule) end)
        |> Enum.map(fn {apis, resources, verbs} ->
          %{
            apiGroups: List.wrap(apis),
            resources: resources,
            verbs: verbs
          }
        end)
        |> Macro.escape()

      skip_observed_generations =
        opts
        |> Keyword.get(:skip_observed_generations, false)
        |> Macro.escape()

      use Supervisor

      import Bonny.Resource, only: [add_owner_reference: 2]

      @behaviour Bonny.ControllerV2

      @spec rules() :: list(map())
      def rules(), do: unquote(rules)

      @spec start_link(term) :: {:ok, pid}
      def start_link(_) do
        Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
      end

      @impl true
      def init(_init_arg) do
        conn = conn()
        list_operation = list_operation()

        watcher_stream =
          __MODULE__
          |> Bonny.Server.Watcher.get_stream(conn, list_operation,
            skip_observed_generations: unquote(skip_observed_generations)
          )
          |> Stream.map(&post_process_resource/1)

        reconciler_stream =
          __MODULE__
          |> Bonny.Server.Reconciler.get_stream(conn, list_operation)
          |> Task.async_stream(&post_process_resource/1)

        children = [
          {Bonny.Server.AsyncStreamRunner,
           id: __MODULE__.WatchServer,
           name: __MODULE__.WatchServer,
           stream: watcher_stream,
           termination_delay: 5_000},
          {Bonny.Server.AsyncStreamRunner,
           id: __MODULE__.ReconcileServer,
           name: __MODULE__.ReconcileServer,
           stream: reconciler_stream,
           termination_delay: 30_000}
        ]

        Supervisor.init(
          children,
          strategy: :one_for_one,
          max_restarts: 20,
          max_seconds: 120
        )
      end

      defp post_process_resource(resource) do
        resource
        |> maybe_set_observed_generation()
        |> Bonny.Resource.apply_status(crd().names.plural, conn())
      end

      if skip_observed_generations do
        defp maybe_set_observed_generation(resource),
          do: Bonny.Resource.set_observed_generation(resource)

        defp maybe_add_obseved_generation_status(crd),
          do:
            Bonny.CRDV2.update_versions(
              crd,
              & &1.storage,
              &Bonny.CRD.Version.add_observed_generation_status/1
            )
      else
        defp maybe_set_observed_generation(resource), do: resource
        defp maybe_add_obseved_generation_status(crd), do: crd
      end

      @impl Bonny.ControllerV2
      def list_operation(), do: Bonny.ControllerV2.list_operation(__MODULE__)

      @impl Bonny.ControllerV2
      defdelegate conn(), to: Bonny.Config

      def crd() do
        __MODULE__
        |> Bonny.ControllerV2.crd()
        |> maybe_add_obseved_generation_status()
      end

      defoverridable list_operation: 0, conn: 0
    end
  end

  @spec crd(module()) :: Bonny.CRDV2.t()
  def crd(controller) do
    names =
      controller
      |> Atom.to_string()
      |> String.split(".")
      |> Enum.reverse()
      |> hd()
      |> CRD.kind_to_names()

    CRD.new!(
      names: names,
      group: Bonny.Config.group(),
      version: Bonny.CRD.Version.new!(name: "v1")
    )
    |> maybe_cutomize_crd(controller)
  end

  defp maybe_cutomize_crd(crd, controller) do
    if function_exported?(controller, :customize_crd, 1),
      do: controller.customize_crd(crd),
      else: crd
  end

  @spec list_operation(module()) :: K8s.Operation.t()
  def list_operation(controller) do
    crd = controller.crd()
    api_version = CRD.resource_api_version(crd)
    kind = crd.names.kind

    case crd.scope do
      :Namespaced -> K8s.Client.list(api_version, kind, namespace: Bonny.Config.namespace())
      _ -> K8s.Client.list(api_version, kind)
    end
  end
end
