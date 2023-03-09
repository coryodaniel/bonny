defmodule Bonny.AdmissionControl.WebhookRouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Bonny.Test.Plug.WebhookHandlerCRD
  alias Bonny.AdmissionControl.WebhookRouter, as: MUT

  describe "call/2" do
    test "return 404 if not POST request" do
      conn =
        conn(:get, "/some_url")
        |> Map.put(:body_params, nil)
        |> MUT.call(webhook_type: :some_type)

      assert conn.status == 404
    end

    test "return 400 if no body given" do
      conn =
        conn(:post, "/some_url")
        |> Map.put(:body_params, nil)
        |> MUT.call(webhook_type: :some_type)

      assert conn.status == 400
    end

    test "return 400 for non-json body" do
      conn =
        conn(:post, "/some_url")
        |> Map.put(:body_params, "")
        |> MUT.call(webhook_type: :some_type)

      assert conn.status == 400
    end

    test "return 400 for json body that is not an admission review" do
      conn =
        conn(:post, "/some_url")
        |> Map.put(:body_params, %{"foo" => "bar"})
        |> MUT.call(webhook_type: :some_type)

      assert conn.status == 400
    end

    test "returns allow: true if no handler" do
      body =
        conn(:post, "/some_url", %{
          "apiVersion" => "admission.k8s.io/v1",
          "kind" => "AdmissionReview",
          "request" => %{"uid" => "some_uid"}
        })
        |> MUT.call(webhook_type: :some_type, handlers: [])
        |> Map.get(:resp_body)
        |> Jason.decode!()

      assert true == get_in(body, ~w(response allowed))
      assert "some_uid" == get_in(body, ~w(response uid))
    end

    test "returns allow: true if webhook not handled" do
      opts = MUT.init(webhook_type: :validating_webhook, handlers: [WebhookHandlerCRD])

      body =
        conn(:post, "/some_url", %{
          "apiVersion" => "admission.k8s.io/v1",
          "kind" => "AdmissionReview",
          "request" => %{"uid" => "some_uid"}
        })
        |> MUT.call(opts)
        |> Map.get(:resp_body)
        |> Jason.decode!()

      assert true == get_in(body, ~w(response allowed))
      assert "some_uid" == get_in(body, ~w(response uid))
    end

    test "returns handler's response if handler processes request" do
      opts = MUT.init(webhook_type: :validating_webhook, handlers: [WebhookHandlerCRD])

      body =
        conn(:post, "/some_url", %{
          "apiVersion" => "admission.k8s.io/v1",
          "kind" => "AdmissionReview",
          "request" => %{
            "uid" => "some_uid",
            "resource" => %{
              "group" => "example.com",
              "version" => "v1",
              "resource" => "testresourcev3s"
            }
          }
        })
        |> MUT.call(opts)
        |> Map.get(:resp_body)
        |> Jason.decode!()

      assert false == get_in(body, ~w(response allowed))
      assert "some_uid" == get_in(body, ~w(response uid))
    end

    test "returns handler's response if handler passed via config" do
      Application.put_env(:bonny_plug, Bonny.AdmissionControl.WebhookPlug,
        handlers: [WebhookHandlerCRD]
      )

      opts = MUT.init(webhook_type: :validating_webhook)

      body =
        conn(:post, "/some_url", %{
          "apiVersion" => "admission.k8s.io/v1",
          "kind" => "AdmissionReview",
          "request" => %{
            "uid" => "some_uid",
            "resource" => %{
              "group" => "example.com",
              "version" => "v1",
              "resource" => "testresourcev3s"
            }
          }
        })
        |> MUT.call(opts)
        |> Map.get(:resp_body)
        |> Jason.decode!()

      assert false == get_in(body, ~w(response allowed))
      assert "some_uid" == get_in(body, ~w(response uid))
    end
  end
end
