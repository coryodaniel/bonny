defmodule Bonny.Server.AsyncStreamMapper do
  use Task, restart: :permanent

  @moduledoc """
  Add the Watcher to your supervision tree in order to watch for events in kubernetes.
  :conn, :stream_generator and :event_handlerl are required keywords.

      children = [
        {Bonny.Server.Watcher,
           name: __MODULE__.WatchServer,
           conn: Bonny.Config.conn(),
           operation: list_operation(),
           event_handler: &__MODULE__.event_handler/2},
           http_opts: []
      ]

      Supervisor.init(children, strategy: :one_for_one)
  """

  @spec start_link(keyword()) :: {:ok, pid}
  def start_link(args) do
    name = Keyword.get(args, :name)
    stream = Keyword.fetch!(args, :stream)
    mapper = Keyword.fetch!(args, :mapper)

    {:ok, pid} = Task.start_link(__MODULE__, :watch, [stream, mapper])

    if !is_nil(name), do: Process.register(pid, name)

    {:ok, pid}
  end

  def watch(stream, mapper) do
    stream
    |> Stream.map(mapper)
    |> Stream.run()
  end
end
