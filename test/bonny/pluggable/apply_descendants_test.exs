defmodule Bonny.Pluggable.ApplyDescendantsTest do
  use ExUnit.Case, async: true
  use Bonny.Axn.Test

  alias Bonny.Pluggable.ApplyDescendants, as: MUT
  alias Bonny.Test.ResourceHelper

  import ExUnit.CaptureLog

  defmodule K8sMock do
    require Logger
    import K8s.Test.HTTPHelper
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

    def request(_method, _url, _body, _headers, _opts) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %HTTPoison.Error{reason: "request not mocked"}}
    end
  end

  setup do
    K8s.Client.DynamicHTTPProvider.register(self(), K8sMock)
    ref = make_ref() |> ResourceHelper.to_string()
    pid = self() |> ResourceHelper.to_string()

    [
      successful_descendant: %{
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
      failing_descendant: %{
        "apiVersion" => "example.com/v1",
        "kind" => "Error",
        "metadata" => %{
          "name" => "error",
          "namespace" => "default",
          "uid" => "error-uid",
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

  test "creates descendants", %{successful_descendant: descendant, ref: ref} do
    opts = MUT.init()

    axn(:add)
    |> Bonny.Axn.register_descendant(descendant)
    |> MUT.call(opts)

    assert_receive %{
      "apiVersion" => "example.com/v1",
      "kind" => "Cog",
      "spec" => %{"ref" => ^ref}
    }
  end

  test "default options", %{successful_descendant: descendant} do
    opts = MUT.init()

    # event is added for :add per default
    axn =
      axn(:add)
      |> Bonny.Axn.register_descendant(descendant)
      |> MUT.call(opts)

    assert 1 == length(axn.events)
    assert hd(axn.events).event_type == :Normal

    # no event is added for :reconcile per default
    axn =
      axn(:reconcile)
      |> Bonny.Axn.register_descendant(descendant)
      |> MUT.call(opts)

    assert Enum.empty?(axn.events)
  end

  test ":events_for_actions option", %{successful_descendant: descendant} do
    opts = MUT.init(events_for_actions: [:add])

    # event is added for :add
    axn =
      axn(:add)
      |> Bonny.Axn.register_descendant(descendant)
      |> MUT.call(opts)

    assert 1 == length(axn.events)
    assert hd(axn.events).event_type == :Normal

    # no event is added for :modify
    axn =
      axn(:modify)
      |> Bonny.Axn.register_descendant(descendant)
      |> MUT.call(opts)

    assert Enum.empty?(axn.events)
  end

  test "failure event is always added", %{failing_descendant: descendant} do
    opts = MUT.init(events_for_actions: [:add])

    log =
      capture_log(fn ->
        assert_raise RuntimeError, ~r/Failed applying descending \(child\) resource/, fn ->
          axn =
            axn(:reconcile)
            |> Bonny.Axn.register_descendant(descendant)
            |> MUT.call(opts)

          assert 1 == length(axn.events)
          assert hd(axn.events).event_type == :Warning
        end
      end)

    assert log =~
             ~s|Failed applying descending (child) resource {"default/error", "example.com/v1", "Kind=Error"}|
  end
end
