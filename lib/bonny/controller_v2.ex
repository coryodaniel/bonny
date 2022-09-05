defmodule Bonny.ControllerV2 do
  alias Bonny.CRDV2, as: CRD

  @doc """
  Should return an operation to list resources for watching and reconciliation.

  Bonny.Controller comes with a default implementation
  """
  @callback list_operation() :: K8s.Operation.t()

  @doc """
  Bonny.Controller comes with a default implementation which returns Bonny.Config.config()
  """
  @callback conn() :: K8s.Conn.t()

  #  Action Callbacks
  @callback add(map()) :: :ok | :error
  @callback modify(map()) :: :ok | :error
  @callback delete(map()) :: :ok | :error
  @callback reconcile(map()) :: :ok | :error

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      crd =
        opts
        |> Keyword.fetch!(:crd)
        |> Keyword.put_new_lazy(:names, fn ->
          __MODULE__
          |> Atom.to_string()
          |> String.split(".")
          |> Enum.reverse()
          |> hd()
          |> CRD.kind_to_names()
        end)
        |> Keyword.put_new(:group, Bonny.Config.group())
        |> Keyword.put_new_lazy(:version, fn -> Bonny.CRD.Version.new!(name: "v1") end)
        |> CRD.new!()
        |> Macro.escape()

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

      use Supervisor

      @behaviour Bonny.ControllerV2

      @spec crd() :: Bonny.CRDV2.t()
      def crd(), do: unquote(crd)

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

        children = [
          {Bonny.Server.AsyncStreamRunner,
           id: __MODULE__.WatchServer,
           name: __MODULE__.WatchServer,
           stream: Bonny.Server.Watcher.get_stream(__MODULE__, conn, list_operation),
           termination_delay: 5_000},
          {Bonny.Server.AsyncStreamRunner,
           id: __MODULE__.ReconcileServer,
           name: __MODULE__.ReconcileServer,
           stream: Bonny.Server.Reconciler.get_stream(__MODULE__, conn, list_operation),
           termination_delay: 30_000}
        ]

        Supervisor.init(
          children,
          strategy: :one_for_one,
          max_restarts: 20,
          max_seconds: 120
        )
      end

      @impl Bonny.ControllerV2
      def list_operation(), do: Bonny.ControllerV2.list_operation(__MODULE__)

      @impl Bonny.ControllerV2
      defdelegate conn(), to: Bonny.Config

      defoverridable list_operation: 0, conn: 0
    end
  end

  @spec list_operation(module()) :: K8s.Operation.t()
  def list_operation(controller) do
    crd = controller.crd()
    api_version = Bonny.CRDV2.resource_api_version(crd)
    kind = crd.names.kind

    case crd.scope do
      :Namespaced -> K8s.Client.list(api_version, kind, namespace: Bonny.Config.namespace())
      _ -> K8s.Client.list(api_version, kind)
    end
  end
end
