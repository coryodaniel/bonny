defmodule Bonny.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      crds()
      |> Enum.map(fn crd ->
        Supervisor.child_spec({Bonny.Watcher, crd}, id: crd)
      end)

    opts = [strategy: :one_for_one, name: Bonny.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def crds(), do: Application.get_env(:bonny, :crds, [])
end
