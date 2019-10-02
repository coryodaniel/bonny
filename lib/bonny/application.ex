defmodule Bonny.Application do
  @moduledoc false

  use Application
  @impl true
  def start(_type, _args) do
    children = Bonny.Config.controllers()

    opts = [strategy: :one_for_one, name: Bonny.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
