defmodule Bonny.Operator.Supervisor do
  @moduledoc false

  use Supervisor

  @spec start_link(list(), atom(), Keyword.t()) :: {:ok, pid}
  def start_link(controllers, operator, init_args) do
    Supervisor.start_link(__MODULE__, {controllers, operator, init_args}, name: operator)
  end

  @impl true
  def init({controllers, operator, init_args}) do
    conn = Keyword.fetch!(init_args, :conn)

    event_recorder_child = {Bonny.EventRecorder, operator: operator}

    controller_children =
      controllers
      |> Enum.map(fn controller ->
        opts = Keyword.merge(controller, operator: operator, conn: conn)
        Supervisor.child_spec({Bonny.ControllerV2, opts}, id: opts[:query])
      end)

    Supervisor.init([event_recorder_child | controller_children], strategy: :one_for_one)
  end
end
