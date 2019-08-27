defmodule K8s.Server.Watcher do
  @moduledoc """
  Continuously watch a list `Operation` for `add`, `modify`, and `delete` events.
  """

  @doc """
  `K8s.Operation` to be watched (K8s.Client.watch)

  ## Examples
  ```elixir
    def watch_operation() do
      K8s.Client.list("v1", :pods, namespace: :all)
    end
  ```
  """
  @callback watch_operation() :: K8s.Operation.t()
  @callback add(map()) :: :ok | :error
  @callback modify(map()) :: :ok | :error
  @callback delete(map()) :: :ok | :error

  # watch_cluster() # Bonny.Config.cluster_name()
  # watch_resources() # default impl, name?

  # @doc "Defines the list `Operation` to watch"
  # @callback operation() :: K8s.Operation.t()

  # defmacro __using__(opts) do
  #   @behaviour Bonny.Server.Reconciler
  #   use GenServer

  # end
end

# defmodule MyWatcher do
#   use Bonny.Server.Watcher, cluster: :default

#   def cluster(), do: :default
#   def run(), do: ...

#   @doc "Operation to watch"
#   @impl true
#   def operation() do
#     K8s.Client.list("v1", :pods, namespaces: :all)
#   end

#   @doc "Resource was added"
#   @impl true
#   def add(resource), do: :ok

#   @doc "Resource was modified"
#   @impl true
#   def modify(resource), do: :ok

#   @doc "Resource was deleted"
#   @impl true
#   def delete(resource), do: :ok
# end
