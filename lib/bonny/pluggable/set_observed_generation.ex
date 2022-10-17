defmodule Bonny.Pluggable.SetObservedGeneration do
  @moduledoc """
  Copies the generation of the resource to the observedGeneration status field.
  ## Options

  `:observed_generation_key` - The key inside the resource status where the observed generation is stored.

  ## Usage

      step Bonny.Pluggable.SkipObservedGenerations,
        observed_generation_key: ~w(internal observedGeneration)
  """

  @behaviour Pluggable
  import Bonny.Axn

  @impl true
  def init(opts \\ []) do
    Keyword.update(opts, :observed_generation_key, ["observedGeneration"], fn keys ->
      [last_key | rest] = Enum.reverse(keys)

      rest
      |> Enum.map(fn
        key when is_binary(key) -> Access.key(key, %{})
        other -> other
      end)
      |> Enum.reverse([last_key])
    end)
  end

  @impl true
  def call(%Bonny.Axn{resource: resource} = axn, opts) do
    observed_generation_key = Keyword.fetch!(opts, :observed_generation_key)

    case resource["metadata"]["generation"] do
      nil -> axn
      generation -> update_status(axn, &put_in(&1, observed_generation_key, generation))
    end
  end
end
