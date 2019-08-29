defmodule Bonny.Server.Watcher.ResourceVersion do
  @moduledoc """
  Get the resourceVersion for a `K8s.Operation`
  """
  @client Application.get_env(:bonny, :k8s_client, K8s.Client)

  @spec get(K8s.Operation.t()) :: {:ok, binary} | {:error, binary}
  def get(operation) do
    cluster = Bonny.Config.cluster_name()

    case @client.run(operation, cluster, params: %{limit: 1}) do
      {:ok, response} ->
        {:ok, extract_rv(response)}

      _ ->
        {:error, "No resource version found for operation: #{inspect(operation)}"}
    end
  end

  @spec extract_rv(map()) :: binary() | {:gone, binary()}
  def extract_rv(%{"metadata" => %{"resourceVersion" => rv}}), do: rv
  def extract_rv(%{"message" => message}), do: {:gone, message}
end
