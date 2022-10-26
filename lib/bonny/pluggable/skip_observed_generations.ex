defmodule Bonny.Pluggable.SkipObservedGenerations do
  @moduledoc """
  Halts the pipelines for a defined list of actions if the observed generation
  equals the resource's generation. It also sets the observed generation value
  before applying the resource status to the cluster.

  ## Options

  `:actions` - The actions for which this rule applies. Defaults to `[:add, :modify]`.
  `:observed_generation_key` - The resource status key where the observed generation is stored. This will be passed to `Kernel.get_in()`. Defaults to `["status", "observedGeneration"]`.

  ## Usage

      step Bonny.Pluggable.SkipObservedGenerations,
        actions: [:add, :modify, :reconcile],
        observed_generation_key: ~w(status internal observedGeneration)
  """

  @behaviour Pluggable
  import Pluggable.Token
  alias Bonny.Axn

  @impl true
  def init(opts \\ []) do
    observed_generation_key =
      Keyword.get(opts, :observed_generation_key, ["status", "observedGeneration"])

    opts
    |> Keyword.put_new(:actions, ~w(add modify)a)
    |> Keyword.put(:observed_generation_key, observed_generation_key)
  end

  @impl true
  def call(%Axn{resource: resource} = axn, opts) do
    actions = Keyword.fetch!(opts, :actions)

    observed_generation_key = Keyword.fetch!(opts, :observed_generation_key)

    cond do
      axn.action not in actions ->
        set_observed_generation(axn, observed_generation_key)

      get_in(resource, ~w(metadata generation)) !=
          get_in(resource, observed_generation_key) ->
        set_observed_generation(axn, observed_generation_key)

      true ->
        halt(axn)
    end
  end

  defp set_observed_generation(axn, ["status" | rest]), do: set_observed_generation(axn, rest)

  defp set_observed_generation(axn, observed_generation_key) do
    case axn.resource["metadata"]["generation"] do
      nil ->
        axn

      generation ->
        accessible_observed_generation_key =
          accessible_observed_generation_key(observed_generation_key)

        Axn.update_status(axn, &put_in(&1, accessible_observed_generation_key, generation))
    end
  end

  defp accessible_observed_generation_key(observed_generation_key) do
    [last_key | rest] = Enum.reverse(observed_generation_key)

    rest
    |> Enum.map(fn
      key when is_binary(key) -> Access.key(key, %{})
      other -> other
    end)
    |> Enum.reverse([last_key])
  end
end
