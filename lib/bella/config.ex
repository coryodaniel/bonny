defmodule Bella.Config do
  @moduledoc """
  Operator configuration interface
  """

  @doc """
  `K8s.Cluster` name used for this operator. Defaults to `:default`
  """
  @spec cluster_name() :: atom
  def cluster_name() do
    Application.get_env(:bella, :cluster_name, :default)
  end
end
