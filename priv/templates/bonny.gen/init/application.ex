defmodule <%= @app_name %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, env: env) do
    opts = [strategy: :one_for_one, name: <%= @app_name %>.Supervisor]
    Supervisor.start_link(children(env), opts)
  end

  # If you want to implement integration tests, remove the following line:
  defp children(:test), do: []
  defp children(env) do
    [
      {<%= @app_name %>.Operator, conn: <%= @app_name %>.K8sConn.get!(env)}
    ]
  end
end
