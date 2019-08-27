defmodule K8s.Server.Watcher do
  @moduledoc """
  Continuously watch a list `Operation` for `add`, `modify`, and `delete` events.
  """

  # watch_operation()
  # watch_cluster() # Bonny.Config.cluster_name()
  # watch_resources() # default impl, name?

  # Reconciler has resources() callback... can that be used?
  # Add a Bonny.Operation behavior? to encapsulate it for both?

  # @doc "Defines the list `Operation` to watch"
  # @callback operation() :: K8s.Operation.t()

  # @doc "Returns the name of the cluster to watch registerd with `K8s.Conn`"
  # @callback cluster() :: atom()

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
