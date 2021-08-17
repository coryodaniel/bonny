defmodule Bella.Naming do
  @moduledoc """
  Naming functions
  """

  @doc """
  Converts an elixir module name to a string for use as the CRD's `kind`.

  ## Examples
      iex> Bella.Naming.module_to_kind(Pod)
      "Pod"

      iex> Bella.Naming.module_to_kind(Controllers.V1.Pod)
      "Pod"
  """
  @spec module_to_kind(atom) :: String.t()
  def module_to_kind(mod) do
    mod
    |> Macro.to_string()
    |> String.split(".")
    |> Enum.reverse()
    |> Enum.at(0)
  end

  @doc """
  Extract the CRD API version from the module name. Defaults to `"v1"`

  ## Examples
      iex> Bella.Naming.module_version(Pod)
      "v1"

      iex> Bella.Naming.module_version(Controllers.V1.Pod)
      "v1"

      iex> Bella.Naming.module_version(Controllers.V1Alpha1.Pod)
      "v1alpha1"
  """
  @spec module_version(atom) :: String.t()
  def module_version(mod) do
    mod
    |> Macro.to_string()
    |> String.split(".")
    |> Enum.reverse()
    |> Enum.at(1, "v1")
    |> String.downcase()
  end
end
