defmodule Bonny.Server.Watcher.ResourceVersion do
  @moduledoc "Get the resourceVersion for a `K8s.Operation`"

  @spec get(K8s.Operation.t()) :: {:ok, binary} | {:error, atom}
  def get(%K8s.Operation{} = operation) do
    case K8s.Client.run(Bonny.Config.conn(), operation, params: [limit: 1]) do
      {:ok, response} ->
        {:ok, extract_rv(response)}

      _ ->
        {:error, :resource_version_not_found}
    end
  end

  @spec extract_rv(map()) :: binary() | {:gone, binary()}
  def extract_rv(%{"metadata" => %{"resourceVersion" => rv}}), do: rv
  def extract_rv(%{"message" => message}), do: {:gone, message}
end
