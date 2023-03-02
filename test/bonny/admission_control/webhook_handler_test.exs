defmodule Bonny.AdmissionControl.WebhookHandlerTest do
  use ExUnit.Case

  alias Bonny.Test.Plug.WebhookHandlerCRD

  import Bonny.Test.CompileTimeAssertions

  describe "__usage__/1" do
    test "Raises an ArgumentError if nothing passed as option" do
      assert_compile_time_raise(
        CompileError,
        "You have to pass the :crd option when using Bonny.AdmissionControl.WebhookHandler",
        fn ->
          use Bonny.AdmissionControl.WebhookHandler
        end
      )
    end

    test "Raises an ArgumentError if invalid CRD passed as option" do
      assert_compile_time_raise(ArgumentError, "cannot invoke @/1 outside module", fn ->
        use Bonny.AdmissionControl.WebhookHandler, crd: %{}
      end)
    end
  end

  describe "process/2" do
    test "processes a request if CRD matches" do
      Application.put_env(:bonny_plug, :admission_review_webhooks, [WebhookHandlerCRD])

      admission_review = %Bonny.AdmissionControl.AdmissionReview{
        request: %{
          "uid" => "some_uid",
          "resource" => %{
            "group" => "example.com",
            "version" => "v1",
            "resource" => "testresourcev3s"
          }
        },
        response: %{}
      }

      admission_review = WebhookHandlerCRD.process(admission_review, :validating_webhook)
      assert false == admission_review.response["allowed"]
    end
  end
end
