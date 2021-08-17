defmodule Bella.Controller do
  @moduledoc """
  `Bella.Controller` defines controller behaviours and generates boilerplate for generating Kubernetes manifests.

  > A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

  Controllers allow for simple `add`, `modify`, `delete`, and `reconcile` handling of custom resources in the Kubernetes API.
  """

  @callback add(map()) :: :ok | :error
  @callback modify(map()) :: :ok | :error
  @callback delete(map()) :: :ok | :error
  @callback reconcile(map()) :: :ok | :error

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bella.Controller
      @client opts[:client] || K8s.Client

      use Supervisor

      def start_link(_) do
        Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
      end

      @impl true
      def init(_init_arg) do
        children = [
          {__MODULE__.WatchServer, name: __MODULE__.WatchServer},
          {__MODULE__.ReconcileServer, name: __MODULE__.ReconcileServer}
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end

      @doc false
      @spec client() :: any()
      def client(), do: @client
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    controller = env.module

    quote bind_quoted: [controller: controller] do
      defmodule WatchServer do
        @moduledoc "Controller watcher implementation"
        use Bella.Server.Watcher

        @impl Bella.Server.Watcher
        defdelegate add(resource), to: controller
        @impl Bella.Server.Watcher
        defdelegate modify(resource), to: controller
        @impl Bella.Server.Watcher
        defdelegate delete(resource), to: controller
      end

      defmodule ReconcileServer do
        @moduledoc "Controller reconciler implementation"
        use Bella.Server.Reconciler, frequency: 30
        @impl Bella.Server.Reconciler
        defdelegate reconcile(resource), to: controller
      end
    end
  end
end
