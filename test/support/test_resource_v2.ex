defmodule TestResourceV2 do
  @moduledoc """
  This controller gets the pid and reference from the resource's spec.
  It then sends a message including that reference, the action and the resource
  name to the pid from the resource.

  A test can therefore create a resource with its own pid (self()), send it
  to kubernetes and wait to receive the message from this controller.
  """

  use Bonny.ControllerV2,
    rbac_rule: {"", ["secrets"], ["get", "watch", "list"]}

  @impl true
  @spec conn() :: K8s.Conn.t()
  def conn(), do: Bonny.Test.IntegrationHelper.conn()

  @impl true
  @spec customize_crd(Bonny.CRDV2.t()) :: Bonny.CRDV2.t()
  def customize_crd(crd) do
    struct!(
      crd,
      versions: [
        Bonny.CRD.Version.new!(
          name: "v1",
          schema: %{
            openAPIV3Schema: %{
              type: :object,
              properties: %{
                spec: %{
                  type: :object,
                  properties: %{
                    pid: %{type: :string},
                    ref: %{type: :string}
                  }
                }
              }
            }
          }
        )
      ]
    )
  end

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
