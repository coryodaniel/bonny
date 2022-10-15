defmodule Bonny.Pluggable.SkipObservedGenerations do
  @moduledoc """
  Halts the pipelines for a defined list of actions if
  the observed generation equals the resource's generation.

  ## Options

  `:actions` - The actions for which this rule applies. Defaults to `[:add, :modify]`.
  `:observed_generation_key` - The key inside the resource status where the observed generation is stored. This will be passed to `Kernel.get_in()`. Defaults to `["observedGeneration"]`.

  ## Usage

      step Bonny.Pluggable.SkipObservedGenerations,
        actions: [:add, :modify, :reconcile],
        observed_generation_key: ~w(internal observedGeneration)
  """

  @behaviour Pluggable
  import Pluggable.Token

  @impl true
  def init(opts \\ []) do
    opts
    |> Keyword.put_new(:actions, ~w(add modify)a)
    |> Keyword.put_new(:observed_generation_key, ~w(observedGeneration))
  end

  @impl true
  def call(%Bonny.Axn{resource: resource} = axn, opts) do
    actions = Keyword.fetch!(opts, :actions)
    observed_generation_key = Keyword.fetch!(opts, :observed_generation_key)

    cond do
      axn.action not in actions ->
        axn

      get_in(resource, ~w(metadata generation)) !=
          get_in(resource, ["status" | observed_generation_key]) ->
        axn

      true ->
        halt(axn)
    end
  end
end
