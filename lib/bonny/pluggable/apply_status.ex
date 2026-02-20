defmodule Bonny.Pluggable.ApplyStatus do
  @moduledoc """
  Applies the status of the given `%Bonny.Axn{}` struct to the status subresource.

  ## Options

    * `:force` and `:field_manager` - Options forwarded to `K8s.Client.apply()`.
    * `:safe_mode` - When `true`, gracefully handles "NotFound" errors that occur when
      a resource is deleted during reconciliation. Instead of crashing, a warning is
      logged and reconciliation continues. Defaults to `false` for backwards compatibility.
      See `Bonny.Axn.safe_apply_status/2` for details.
      **Recommended to set to `true` in production** to avoid crashes when resources
      are deleted while being reconciled.

  ## Examples

      # Standard usage
      step Bonny.Pluggable.ApplyStatus, field_manager: "MyOperator", force: true

      # With safe mode enabled (recommended for production)
      step Bonny.Pluggable.ApplyStatus, safe_mode: true, field_manager: "MyOperator"
  """

  @behaviour Pluggable

  @impl true
  def init(opts \\ []) do
    opts
    |> Keyword.validate!([:field_manager, :force, :safe_mode])
    |> Keyword.put_new(:safe_mode, Application.get_env(:bonny, :apply_status_safe_mode, false))
  end

  @impl true
  def call(axn, apply_opts) when axn.action != :delete do
    {safe_mode, k8s_opts} = Keyword.pop!(apply_opts, :safe_mode)

    if safe_mode do
      Bonny.Axn.safe_apply_status(axn, k8s_opts)
    else
      Bonny.Axn.apply_status(axn, k8s_opts)
    end
  end

  def call(axn, _apply_opts), do: axn
end
