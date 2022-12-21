defmodule Bonny.Pluggable.LoggerTest do
  use ExUnit.Case, async: true
  use Bonny.Axn.Test
  import ExUnit.CaptureLog

  alias Bonny.Pluggable.Logger, as: MUT
  alias Bonny.Test.ResourceHelper

  defmodule K8sMock do
    require Logger
    import K8s.Client.HTTPTestHelper
    alias Bonny.Test.ResourceHelper

    def request(
          :patch,
          %URI{path: "apis/example.com/v1/namespaces/default/cogs/bar"},
          body,
          _headers,
          _opts
        ) do
      render(Jason.decode!(body))
    end

    def request(
          :patch,
          %URI{path: "apis/example.com/v1/namespaces/default/widgets/foo/status"},
          body,
          _headers,
          _opts
        ) do
      render(Jason.decode!(body))
    end

    def request(
          :patch,
          %URI{path: "apis/events.k8s.io/v1/namespaces/default/events/foo." <> _},
          body,
          _headers,
          _opts
        ) do
      render(Jason.decode!(body))
    end

    def request(_method, _uri, _body, _headers, _opts) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %K8s.Client.HTTPError{message: "request not mocked"}}
    end
  end

  setup do
    K8s.Client.DynamicHTTPProvider.register(self(), K8sMock)
    {:ok, _} = start_supervised({Bonny.EventRecorder, operator: __MODULE__})

    [
      axn: axn(:add, resource: ResourceHelper.widget()) |> struct!(operator: __MODULE__)
    ]
  end

  test "logs action events", %{axn: axn} do
    captured_log =
      capture_log([level: :error], fn ->
        opts = MUT.init(level: :error)

        axn
        |> MUT.call(opts)
      end)

    assert captured_log =~
             ~s|{"default/foo", "example.com/v1", "Kind=Widget, Action=:add"} - Processing event|
  end

  test "logs when status is applied", %{axn: axn} do
    captured_log =
      capture_log([level: :error], fn ->
        opts = MUT.init(level: :error)

        axn
        |> MUT.call(opts)
        |> Bonny.Axn.update_status(fn _ -> %{"foo" => "bar"} end)
        |> Bonny.Axn.apply_status()
      end)

    assert captured_log =~
             ~s|{"default/foo", "example.com/v1", "Kind=Widget, Action=:add"} - Applying status|
  end

  test "logs when descendants are applied", %{axn: axn} do
    captured_log =
      capture_log([level: :error], fn ->
        opts = MUT.init(level: :error)

        axn
        |> MUT.call(opts)
        |> Bonny.Axn.register_descendant(ResourceHelper.cog())
        |> Bonny.Axn.apply_descendants()
      end)

    assert captured_log =~
             ~s|{"default/foo", "example.com/v1", "Kind=Widget, Action=:add"} - Applying descendant {"default/bar", "example.com/v1", "Kind=Cog"}|
  end

  test "logs when events are emitted", %{axn: axn} do
    captured_log =
      capture_log([level: :error], fn ->
        opts = MUT.init(level: :error)

        axn
        |> MUT.call(opts)
        |> Bonny.Axn.success_event()
        |> Bonny.Axn.emit_events()
      end)

    assert captured_log =~
             ~s|{"default/foo", "example.com/v1", "Kind=Widget, Action=:add"} - Emitting Normal event|
  end
end
