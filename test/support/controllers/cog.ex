# credo:disable-for-this-file
defmodule Cog do
  @moduledoc false
  use Bonny.Controller
  require Logger

  @impl true
  @spec add(map()) :: :ok | :error
  def add(obj), do: Logger.info("add: #{inspect(obj)}")

  @impl true
  @spec modify(map()) :: :ok | :error
  def modify(obj), do: Logger.info("modify: #{inspect(obj)}")

  @impl true
  @spec delete(map()) :: :ok | :error
  def delete(obj), do: Logger.info("delete: #{inspect(obj)}")

  @impl true
  @spec reconcile(map()) :: :ok | :error
  def reconcile(obj), do: Logger.info("reconcile: #{inspect(obj)}")
end
