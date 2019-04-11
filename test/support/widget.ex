defmodule Widget do
  @moduledoc false
  use Bonny.Controller
  require Logger

  @rule {"apps", ["deployments", "services"], ["*"]}
  @rule {"", ["configmaps"], ["create", "read"]}

  @spec add(map()) :: :ok | :error | {:error, binary}
  def add(obj), do: Logger.info("add: #{inspect(obj)}")

  @spec modify(map()) :: :ok | :error | {:error, binary}
  def modify(obj), do: Logger.info("modify: #{inspect(obj)}")

  @spec delete(map()) :: :ok | :error | {:error, binary}
  def delete(obj), do: Logger.info("delete: #{inspect(obj)}")

  @spec reconcile(map()) :: :ok | :error | {:error, binary}
  def reconcile(obj), do: Logger.info("reconcile: #{inspect(obj)}")
end
