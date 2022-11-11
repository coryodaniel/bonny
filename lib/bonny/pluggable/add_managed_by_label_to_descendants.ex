defmodule Bonny.Pluggable.AddManagedByLabelToDescendants do
  @moduledoc """
  Adds the `app.kubernetes.io/managed-by` label to all descendants registered
  within the pipeline.

  Add this to your operator or controllers to set this label to a value of
  your choice.

  ## Options

    * `:managed_by` - Required. The value the label should be set to.

  ## Examples

      step Bonny.Pluggable.AddManagedByLabelToDescendants,
        managed_by: Bonny.Config.name()

  """

  @behaviour Pluggable

  @impl Pluggable
  def init(opts) do
    Keyword.fetch!(opts, :managed_by)
  end

  @label "app.kubernetes.io/managed-by"
  @impl Pluggable
  def call(axn, managed_by) do
    axn
    |> Bonny.Axn.register_before_apply_descendants(fn descendants, _axn ->
      Enum.map(descendants, &Bonny.Resource.set_label(&1, @label, managed_by))
    end)
  end
end
