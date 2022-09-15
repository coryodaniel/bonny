defmodule Bonny.Controller do
  @moduledoc """
  `Bonny.Controller` defines controller behaviours and generates boilerplate for generating Kubernetes manifests.

  > A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

  Controllers allow for simple `add`, `modify`, `delete`, and `reconcile` handling of custom resources in the Kubernetes API.
  """

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
  @deprecated "Use `Bonny.ControllerV2` instead."
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      Module.register_attribute(__MODULE__, :rule, accumulate: true)
      @behaviour Bonny.Controller

      # CRD defaults
      @group Bonny.Config.group()
      @kind Bonny.Naming.module_to_kind(__MODULE__)
      @scope :namespaced
      @version Bonny.Naming.module_version(__MODULE__)

      @singular Macro.underscore(Bonny.Naming.module_to_kind(__MODULE__))
      @plural "#{@singular}s"
      @names %{}

      @additional_printer_columns []
      @before_compile Bonny.Controller

      use Supervisor

      import Bonny.Resource, only: [add_owner_reference: 2]

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

      @impl Bonny.Controller
      def list_operation(), do: Bonny.Controller.list_operation(__MODULE__)

      @impl Bonny.Controller
      defdelegate conn(), to: Bonny.Config

      defoverridable list_operation: 0, conn: 0
    end
  end

  @doc false
  defmacro __before_compile__(%{module: controller}) do
    additional_printer_columns =
      case Module.get_attribute(controller, :additional_printer_columns, []) do
        [] -> quote do: []
        _ -> quote do: @additional_printer_columns ++ Bonny.CRD.default_columns()
      end

    quote do
      @doc """
      Returns the `Bonny.CRD.t()` the controller manages the lifecycle of.
      """
      @spec crd() :: Bonny.CRD.t()
      def crd() do
        %Bonny.CRD{
          group: @group,
          scope: @scope,
          version: @version,
          names: Map.merge(default_names(), @names),
          additional_printer_columns: additional_printer_columns()
        }
      end

      @doc """
      A list of RBAC rules that this controller needs to operate.

      This list will be serialized into the operator manifest when using `mix bonny.gen.manifest`.
      """
      @spec rules() :: list(map())
      def rules() do
        Enum.reduce(@rule, [], fn {api, resources, verbs}, acc ->
          rule = %{
            apiGroups: [api],
            resources: resources,
            verbs: verbs
          }

          [rule | acc]
        end)
      end

      @spec default_names() :: map()
      defp default_names() do
        %{
          plural: @plural,
          singular: @singular,
          kind: @kind,
          shortNames: nil
        }
      end

      defp additional_printer_columns(), do: unquote(additional_printer_columns)
    end
  end

  @spec list_operation(module()) :: K8s.Operation.t()
  def list_operation(controller) do
    crd = controller.crd()
    api_version = Bonny.CRD.api_version(crd)
    kind = Bonny.CRD.kind(crd)

    case crd.scope do
      :namespaced -> K8s.Client.list(api_version, kind, namespace: Bonny.Config.namespace())
      _ -> K8s.Client.list(api_version, kind)
    end
  end
end
