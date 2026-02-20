defmodule Bonny.Pluggable.ApplyStatusTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use Bonny.Axn.Test

  import ExUnit.CaptureLog

  require Logger

  alias Bonny.Pluggable.ApplyStatus, as: MUT
  alias Bonny.Test.ResourceHelper

  defmodule K8sMock do
    require Logger
    import K8s.Client.HTTPTestHelper
    alias Bonny.Test.ResourceHelper

    def request(:patch, %URI{} = uri, body, _headers, _opts) do
      resource = Jason.decode!(body)

      case get_in(resource, ["status", "scenario"]) do
        "ok" ->
          if ref = get_in(resource, ["status", "ref"]) do
            send(self(), {:status_applied, ResourceHelper.string_to_ref(ref), uri.query})
          end

          render(resource)

        "not_found" ->
          name = get_in(resource, ["metadata", "name"])
          {:error, %K8s.Client.HTTPError{message: ~s|resource "#{name}" not found|}}

        "other_error" ->
          {:error, %K8s.Client.HTTPError{message: "some error"}}

        other ->
          {:error, %K8s.Client.HTTPError{message: "invalid status.scenario: #{inspect(other)}"}}
      end
    end

    def request(_method, _uri, _body, _headers, _opts) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %K8s.Client.HTTPError{message: "request not mocked"}}
    end
  end

  setup do
    K8s.Client.DynamicHTTPProvider.register(self(), K8sMock)
    :ok
  end

  defp with_status(axn, scenario, attrs \\ %{}) do
    status = Map.merge(%{"scenario" => scenario}, attrs)
    Bonny.Axn.update_status(axn, fn _ -> status end)
  end

  describe "init/1" do
    test "defaults safe_mode to false" do
      opts = MUT.init()
      assert opts[:safe_mode] == false
    end

    test "accepts safe_mode option" do
      opts = MUT.init(safe_mode: true)
      assert opts[:safe_mode] == true
    end

    test "accepts field_manager and force options" do
      opts = MUT.init(field_manager: "TestOperator", force: true)
      assert opts[:field_manager] == "TestOperator"
      assert opts[:force] == true
    end

    test "raises on unknown options" do
      assert_raise ArgumentError, fn ->
        MUT.init(safe_mode: true, unknown: "value")
      end
    end
  end

  describe "call/2" do
    setup do
      previous_level = Logger.level()
      Logger.configure(level: :debug)
      on_exit(fn -> Logger.configure(level: previous_level) end)
      :ok
    end

    test "skips apply_status when action is :delete" do
      ref = make_ref()

      axn =
        axn(:delete)
        |> with_status("ok", %{"ref" => ResourceHelper.to_string(ref)})

      result = MUT.call(axn, MUT.init(safe_mode: true))
      assert result == axn
      refute_receive {:status_applied, ^ref, _}
    end

    test "applies status and forwards options when safe_mode is false" do
      ref = make_ref()

      axn =
        axn(:reconcile)
        |> with_status("ok", %{"ref" => ResourceHelper.to_string(ref)})

      result =
        MUT.call(
          axn,
          MUT.init(safe_mode: false, field_manager: "MyOperator", force: true)
        )

      assert_receive {:status_applied, ^ref, query}
      params = URI.decode_query(query || "")
      assert params["fieldManager"] == "MyOperator"
      assert params["force"] == "true"
      assert result != axn
    end

    test "delegates to safe_apply_status when safe_mode is true" do
      axn = axn(:reconcile) |> with_status("not_found")

      log =
        capture_log([level: :debug], fn ->
          result = MUT.call(axn, MUT.init(safe_mode: true))
          # safe_apply_status returns axn without marking status as applied
          assert result.status == %{"scenario" => "not_found"}
          assert result.resource["status"] == %{"scenario" => "not_found"}
        end)

      assert log =~ "Skipping status update"
      assert log =~ "resource was deleted during reconciliation"
    end

    test "with safe_mode: false, raises on not found errors" do
      assert_raise RuntimeError, ~r/not found/, fn ->
        axn(:reconcile)
        |> with_status("not_found")
        |> MUT.call(MUT.init(safe_mode: false))
      end
    end

    test "with safe_mode: true, re-raises non-not-found errors" do
      assert_raise RuntimeError, ~r/some error/, fn ->
        axn(:reconcile)
        |> with_status("other_error")
        |> MUT.call(MUT.init(safe_mode: true))
      end
    end
  end
end
