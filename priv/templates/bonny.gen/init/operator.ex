defmodule <%= @app_name %>.Operator do
  @moduledoc """
  Defines the operator.

  The operator resource defines custom resources, watch queries and their
  controllers and serves as the entry point to the watching and handling
  processes.
  """

  use Bonny.Operator, default_watch_namespace: "default"

  step Bonny.Pluggable.Logger, level: :info
  step :delegate_to_controller
  step Bonny.Pluggable.ApplyStatus
  step Bonny.Pluggable.ApplyDescendants

  @impl Bonny.Operator
  def controllers(watching_namespace, _opts) do
    <%= if @controllers do %>
      <%= Macro.to_string(@controllers) %>
    <% else %>
      [
        # Add your controllers here.
        # %{
        #  query: K8s.Client.watch("<%= @api_group %>/v1", "MyCustomResource", namespace: watching_namespace),
        #  controller: <%= @app_name %>.Controller.MyCustomResourceController
        # }
      ]
    <% end %>
  end

  @impl Bonny.Operator
  def crds() do
    <%= inspect(@crds, pretty: true) %>
  end
end
