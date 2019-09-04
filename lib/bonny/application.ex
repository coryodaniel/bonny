defmodule Bonny.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # watchers =
    #   Bonny.Config.controllers()
    #   |> Enum.map(fn controller ->
    #     Supervisor.child_spec({Bonny.Watcher, controller}, id: controller)
    #   end)

    # TODO start each controller
    # children = [reconciler | watchers]
    children = []
    opts = [strategy: :one_for_one, name: Bonny.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
