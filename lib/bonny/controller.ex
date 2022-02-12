defmodule Bonny.Controller do
  @moduledoc """
  `Bonny.Controller` defines controller behaviours and generates boilerplate for generating Kubernetes manifests.

  > A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

  Controllers allow for simple `add`, `modify`, `delete`, and `reconcile` handling of custom resources in the Kubernetes API.
  """

  @callback add(map()) :: :ok | :error
  @callback modify(map()) :: :ok | :error
  @callback delete(map()) :: :ok | :error
  @callback reconcile(map()) :: :ok | :error
  @callback list_operation() :: K8s.Operation.t()
  @callback conn() :: K8s.Conn.t()

  @doc false
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

      def start_link(_) do
        Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
      end

      @impl true
      def init(_init_arg) do
        {:ok, reconcilation_stream} = K8s.Client.stream(conn(), list_operation())

        children = [
          {Bonny.Server.AsyncStreamMapper,
           name: __MODULE__.WatchServer,
           stream: K8s.Client.watch_and_stream(conn(), list_operation(), []),
           mapper: &Bonny.Controller.event_handler(__MODULE__, &1)},
          {Bonny.Server.StreamReconciler,
           name: __MODULE__.ReconcileServer,
           resource_stream: reconcilation_stream,
           reconcile: &Bonny.Controller.reconcile(__MODULE__, &1)}
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end

      def list_operation(), do: Bonny.Controller.list_operation(__MODULE__)

      def conn(), do: Bonny.Config.conn()

      defoverridable list_operation: 0, conn: 0
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    controller = env.module

    quote bind_quoted: [controller: controller] do
      @doc """
      Returns the `Bonny.CRD.t()` the controller manages the lifecycle of.
      """
      @spec crd() :: %Bonny.CRD{}
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

      @spec additional_printer_columns() :: list(map())
      defp additional_printer_columns() do
        case @additional_printer_columns do
          [] -> []
          _ -> @additional_printer_columns ++ Bonny.CRD.default_columns()
        end
      end
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

  @spec event_handler(module(), map()) :: any()
  def event_handler(controller, %{"type" => type, "object" => resource}) do
    case type do
      "ADDED" -> controller.add(resource)
      "MODIFIED" -> controller.modify(resource)
      "DELETED" -> controller.delete(resource)
    end
  end

  @spec reconcile(module(), map()) :: any()
  def reconcile(controller, resource), do: controller.reconcile(resource)
end
