defmodule Bonny.Pluggable.ApplyStatus do
  @moduledoc """
  Applies the status of the given `%Bonny.Axn{}` struct to the status subresource.

  ## Options

    * `:force` and `:field_manager` - Options forwarded to `K8s.Client.apply()`.

  ## Examples

      step Bonny.Pluggable.ApplyStatus, field_manager: "MyOperator", force: true
  """

  @behaviour Pluggable

  @impl true
  def init(opts \\ []), do: Keyword.take(opts, [:field_manager, :force])

  @impl true
  def call(axn, apply_opts) do
    Bonny.Axn.apply_status(axn, apply_opts)
  end
end
