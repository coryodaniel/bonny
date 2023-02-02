defmodule <%= @app_name %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, env: env) do
    children = [{<%= @app_name %>.Operator, conn: <%= @app_name %>.K8sConn.get!(env)}]

    opts = [strategy: :one_for_one, name: <%= @app_name %>.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
