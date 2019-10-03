defmodule Bonny.PeriodicTask do
  @moduledoc """
  Register periodically run tasks.
  Use for running tasks as a part of reconciling a CRD with a lifetime, duration, or interval field.

  __Note:__ Must be started by your operator.

  Add `Bonny.PeriodicTask.sttart_link(:ok)` to your application.

  Functions are expected to return one of:
  - `:ok` - task will be passed to subsequent calls
  - `{:ok, new_state}` state field will be updated in task and provided to next call
  - `{:stop, reason}` task will be removed from execution loop. Use for tasks opting out of being re-run
  - `any()` - any other result is treated as an error, and the execution loop will be halted

  ## Examples

    Registering a task
      iex> Bonny.PeriodicTask.new(:pod_evictor, {PodEvictor, :evict, [reconcile_payload_map]}, 5000)

    Unregistering a task
      iex> Bonny.PeriodicTask.unregister(:pod_evictor)

  """
  use DynamicSupervisor
  alias Bonny.Sys.Event

  @enforce_keys [:handler, :id]
  defstruct handler: nil, id: nil, interval: 1000, jitter: 0.0, state: nil

  @type t :: %__MODULE__{
          handler: fun() | mfa(),
          interval: pos_integer(),
          jitter: float(),
          id: binary(),
          state: any()
        }

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_any) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Registers and starts a new task given `Bonny.PeriodicTask` attributes"
  @spec new(atom, mfa() | fun(), pos_integer() | nil) :: {:ok, pid} | {:error, term()}
  def new(id, handler, interval \\ 5000) do
    register(%__MODULE__{
      id: id,
      handler: handler,
      interval: interval
    })
  end

  @doc "Registers and starts a new `Bonny.PeriodicTask`"
  @spec register(t()) :: {:ok, pid} | {:error, term()}
  def register(%__MODULE__{id: id} = task) do
    Event.task_registered(%{}, %{id: id})
    DynamicSupervisor.start_child(__MODULE__, {Bonny.PeriodicTask.Runner, task})
  end

  @doc "Unregisters and stops a `Bonny.PeriodicTask`"
  @spec unregister(t() | atom()) :: any()
  def unregister(%__MODULE__{id: id}), do: unregister(id)

  def unregister(id) when is_atom(id) do
    Event.task_unregistered(%{}, %{id: id})

    case Process.whereis(id) do
      nil ->
        :ok

      pid ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
end
