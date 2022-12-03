defmodule Bonny.Pluggable.AddManagedByLabelToDescendantsTest do
  use ExUnit.Case, async: true
  use Bonny.Axn.Test

  alias Bonny.Pluggable.AddManagedByLabelToDescendants, as: MUT
  alias Bonny.Test.ResourceHelper

  defmodule K8sMock do
    require Logger
    import K8s.Client.HTTPTestHelper
    alias Bonny.Test.ResourceHelper

    def request(:patch, "apis/example.com/v1/namespaces/default/cogs/bar", body, _headers, _opts) do
      resource = Jason.decode!(body)
      dest = ResourceHelper.string_to_pid(resource["spec"]["pid"])
      send(dest, resource)
      render(resource)
    end

    def request(
          :patch,
          "apis/example.com/v1/namespaces/default/errors/error",
          _body,
          _headers,
          _opts
        ) do
      {:error, %HTTPoison.Error{reason: "some error"}}
    end
  end

  setup do
    K8s.Client.DynamicHTTPProvider.register(self(), K8sMock)
    ref = make_ref() |> ResourceHelper.to_string()
    pid = self() |> ResourceHelper.to_string()

    [
      descendant: %{
        "apiVersion" => "example.com/v1",
        "kind" => "Cog",
        "metadata" => %{
          "name" => "bar",
          "namespace" => "default",
          "uid" => "bar-uid",
          "generation" => 1
        },
        "spec" => %{
          "ref" => ref,
          "pid" => pid
        }
      },
      ref: ref
    ]
  end

  test "Sets the label as expected", %{descendant: descendant, ref: ref} do
    axn(:add)
    |> MUT.call(MUT.init(managed_by: "test-operator"))
    |> register_descendant(descendant, omit_owner_ref: true)
    |> apply_descendants()

    assert_receive %{
      "apiVersion" => "example.com/v1",
      "kind" => "Cog",
      "metadata" => %{
        "labels" => %{
          "app.kubernetes.io/managed-by" => "test-operator"
        }
      },
      "spec" => %{"ref" => ^ref}
    }
  end
end
