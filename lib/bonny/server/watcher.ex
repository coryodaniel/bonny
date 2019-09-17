defmodule Bonny.Server.Watcher do
  @moduledoc """
  Continuously watch a list `Operation` for `add`, `modify`, and `delete` events.
  """

  # TODO: moduledoc, docs, and examples
  @callback add(map()) :: :ok | :error
  @callback modify(map()) :: :ok | :error
  @callback delete(map()) :: :ok | :error

  @doc """
  [`K8s.Operation`](https://hexdocs.pm/k8s/K8s.Operation.html) to watch.

  ## Examples
    Log all pod lifecycle events
    ```elixir
      defmodule PodLifecycleLogger do
        use Bonny.Server.Watcher

        @impl true
        def watch_operation() do
          K8s.Client.list("v1", :pods, namespace: :all)
        end

        @impl true
        def add(pod) do
          log_event(:add, pod)
        end

        @impl true
        def modify(pod) do
          log_event(:modify, pod)
        end

        @impl true
        def delete(pod) do
          log_event(:delete, pod)
        end

        @spec log_event(atom, map) :: :ok
        def log_event(type, pod) do
          name = get_in(pod, ["metadata", "name"])
          namespace = get_in(pod, ["metadata", "namepace"]) || "default"
          # log type,name,namespace here
        end
      end
    ```
  """
  @callback watch_operation() :: K8s.Operation.t()

  alias Bonny.Server.Watcher.{State, ResourceVersion, ResponseBuffer}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bonny.Server.Watcher
      use GenServer
      @initial_delay opts[:initial_delay] || 500
      @client opts[:client] || K8s.Client

      alias Bonny.Server.Watcher.State

      def start_link(), do: start_link([])

      def start_link(opts) do
        GenServer.start_link(__MODULE__, :ok, opts)
      end

      @doc false
      @spec client() :: any()
      def client(), do: @client

      @impl GenServer
      def init(:ok) do
        Bonny.Sys.Event.watcher_initialized(%{}, %{module: __MODULE__})
        Process.send_after(self(), :watch, @initial_delay)
        {:ok, State.new()}
      end

      @impl GenServer
      def handle_info(:watch, %State{} = state) do
        rv =
          case state.resource_version do
            nil ->
              resp = Bonny.Server.Watcher.ResourceVersion.get(watch_operation())

              case resp do
                {:ok, rv} ->
                  rv

                {:error, _} ->
                  "0"
              end

            rv ->
              rv
          end

        Bonny.Sys.Event.watcher_watch_started(%{}, %{module: __MODULE__})
        Bonny.Server.Watcher.watch(__MODULE__, rv, self())
        {:noreply, state}
      end

      @impl GenServer
      def handle_info(%HTTPoison.AsyncHeaders{}, state), do: {:noreply, state}

      @impl GenServer
      def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
        Bonny.Sys.Event.watcher_watch_succeeded(%{}, %{module: __MODULE__})
        {:noreply, state}
      end

      @impl GenServer
      def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
        Bonny.Sys.Event.watcher_watch_failed(%{}, %{module: __MODULE__, code: code})
        {:stop, :normal, state}
      end

      @impl GenServer
      def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, %State{resource_version: rv} = state) do
        Bonny.Sys.Event.watcher_chunk_received(%{}, %{module: __MODULE__, rv: rv})

        {lines, buffer} =
          state.buffer
          |> Bonny.Server.Watcher.ResponseBuffer.add_chunk(chunk)
          |> Bonny.Server.Watcher.ResponseBuffer.get_lines()

        case Bonny.Server.Watcher.process_lines(lines, rv, __MODULE__) do
          {:ok, new_rv} ->
            {:noreply, %State{state | buffer: buffer, resource_version: new_rv}}

          {:error, :gone} ->
            {:stop, :normal, state}
        end
      end

      @impl GenServer
      def handle_info(%HTTPoison.AsyncEnd{}, %State{} = state) do
        Bonny.Sys.Event.watcher_watch_finished(%{}, %{module: __MODULE__})
        send(self(), :watch)
        {:noreply, state}
      end

      @impl GenServer
      def handle_info(%HTTPoison.Error{reason: {:closed, :timeout}}, %State{} = state) do
        Bonny.Sys.Event.watcher_watch_timedout(%{}, %{module: __MODULE__})
        send(self(), :watch)
        {:noreply, state}
      end

      @impl GenServer
      def handle_info({:DOWN, _ref, :process, pid, reason}, %State{} = state) do
        Bonny.Sys.Event.watcher_genserver_down(%{}, %{module: __MODULE__})

        {:stop, :normal, state}
      end

      @impl GenServer
      def handle_info(_other, %State{} = state) do
        {:noreply, state}
      end
    end
  end

  @spec watch(module(), binary(), pid()) :: no_return
  def watch(module, rv, pid) do
    operation = module.watch_operation()
    cluster = Bonny.Config.cluster_name()
    timeout = 5 * 60 * 1000
    client = module.client()

    client.watch(operation, cluster,
      params: %{resourceVersion: rv},
      stream_to: pid,
      recv_timeout: timeout
    )

    nil
  end

  @spec process_lines(list(binary()), binary(), module()) :: {:ok, binary} | {:error, :gone}
  def process_lines(lines, rv, module) do
    Enum.reduce(lines, {:ok, rv}, fn line, status ->
      case status do
        {:ok, current_rv} ->
          process_line(line, current_rv, module)

        {:error, :gone} ->
          {:error, :gone}
      end
    end)
  end

  @spec process_line(binary(), binary(), module()) :: {:ok, binary} | {:error, :gone}
  def process_line(line, current_rv, module) do
    %{"type" => type, "object" => raw_object} = Jason.decode!(line)

    case ResourceVersion.extract_rv(raw_object) do
      {:gone, _message} ->
        {:error, :gone}

      ^current_rv ->
        {:ok, current_rv}

      new_rv ->
        dispatch(%{"type" => type, "object" => raw_object}, module)
        {:ok, new_rv}
    end
  end

  @doc """
  Dispatches an `ADDED`, `MODIFIED`, and `DELETED` events to an controller
  """
  @spec dispatch(map, atom) :: no_return
  def dispatch(%{"type" => "ADDED", "object" => object}, controller),
    do: do_dispatch(controller, :add, object)

  def dispatch(%{"type" => "MODIFIED", "object" => object}, controller),
    do: do_dispatch(controller, :modify, object)

  def dispatch(%{"type" => "DELETED", "object" => object}, controller),
    do: do_dispatch(controller, :delete, object)

  @spec do_dispatch(atom, atom, map) :: no_return
  defp do_dispatch(controller, event, object) do
    Task.start(fn ->
      apply(controller, event, [object])
    end)
  end
end
