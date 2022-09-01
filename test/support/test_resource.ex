defmodule TestResource do
  @moduledoc false
  use Bonny.Controller

  @names %{
    plural: "test-resource",
    singular: "test-resource",
    kind: "TestResource",
    shortNames: nil
  }

  @spec conn() :: K8s.Conn.t()
  def conn(), do: Bonny.Test.IntegrationHelper.conn()

  @impl true
  def add(resource), do: respond(resource, :created)
  @impl true
  def modify(resource), do: respond(resource, :modified)
  @impl true
  def delete(resource), do: respond(resource, :deleted)
  @impl true
  def reconcile(resource), do: respond(resource, :reconciled)

  defp parse_pid(pid), do: pid |> String.to_charlist() |> :erlang.list_to_pid()
  defp parse_ref(ref), do: ref |> String.to_charlist() |> :erlang.list_to_ref()

  defp respond(resource, action) do
    pid = resource |> get_in(["spec", "pid"]) |> parse_pid()
    ref = resource |> get_in(["spec", "ref"]) |> parse_ref()
    name = resource |> get_in(["metadata", "name"])

    send(pid, {ref, action, name})
    :ok
  end
end
