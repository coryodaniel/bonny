defmodule Bonny.AdmissionControl.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Bonny.Test.AdmissionControlHelper
  alias Bonny.AdmissionControl.AdmissionReview
  alias Bonny.AdmissionControl.Plug, as: MUT

  describe "init/1" do
    test "raises if webhook_type is not declared" do
      assert_raise(CompileError, ~r/requires you to define the :webhook_type option/, fn ->
        MUT.init(webhook_handler: SomeModule)
      end)
    end

    test "raises if webhook_type is not :validating or :mutating" do
      assert_raise(CompileError, ~r/requires you to define the :webhook_type option/, fn ->
        MUT.init(webhook_handler: SomeModule, webhook_type: :invalid)
      end)
    end

    test "raises if webhook_handler is not declared" do
      assert_raise(CompileError, ~r/requires you to set the :webhook_handler option/, fn ->
        MUT.init(webhook_type: :validating)
      end)
    end

    test "turns webhook_handler into {module, opts} tuple" do
      opts = MUT.init(webhook_type: :validating, webhook_handler: SomeModule)
      assert opts.webhook_handler == {SomeModule, []}
    end

    defmodule InitTestHandler do
      def init(:foo), do: :bar
    end

    test "calls handler's init function if tuple is given" do
      opts = MUT.init(webhook_type: :validating, webhook_handler: {InitTestHandler, :foo})
      assert opts.webhook_handler == {InitTestHandler, :bar}
    end
  end

  defmodule CallTestHandler do
    def call(admission_webhook, opts) do
      case opts[:result] do
        :deny -> AdmissionReview.deny(admission_webhook)
        _ -> admission_webhook
      end
    end
  end

  describe "call/2" do
    test "calls the handler and returns plug" do
      response =
        AdmissionControlHelper.webhook_request_conn()
        |> MUT.call(%{webhook_type: :validation, webhook_handler: {CallTestHandler, []}})
        |> Map.get(:resp_body)
        |> Jason.decode!()

      assert %{
               "apiVersion" => "admission.k8s.io/v1",
               "kind" => "AdmissionReview",
               "response" => %{
                 "allowed" => true
               }
             } = response
    end

    test "calls the handler and returns allowed false" do
      response =
        AdmissionControlHelper.webhook_request_conn()
        |> MUT.call(%{
          webhook_type: :validation,
          webhook_handler: {CallTestHandler, [result: :deny]}
        })
        |> Map.get(:resp_body)
        |> Jason.decode!()

      assert false == response["response"]["allowed"]
    end
  end
end
