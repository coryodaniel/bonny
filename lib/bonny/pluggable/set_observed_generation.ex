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

  @impl true
  def init(opts \\ []) do
    observed_generation_key = Keyword.get(opts, :observed_generation_key, ["observedGeneration"])

    [last_key | rest] = Enum.reverse(observed_generation_key)

    rest
    |> Enum.map(fn
      key when is_binary(key) -> Access.key(key, %{})
      other -> other
    end)
    |> Enum.reverse([last_key])
  end

  @impl true
  def call(%Bonny.Axn{resource: resource} = axn, observed_generation_key) do
    case resource["metadata"]["generation"] do
      nil -> axn
      generation -> Bonny.Axn.update_status(axn, &put_in(&1, observed_generation_key, generation))
    end
  end
end
