defmodule Bonny.AdmissionControl.Router do
  import Plug.Conn

  alias Bonny.AdmissionControl.AdmissionReview

  @api_version "admission.k8s.io/v1"
  @kind "AdmissionReview"

  @mutating_webhook_path "/admission-review/mutating"
  @validating_webhook_path "/admission-review/validating"

  defmacro __using__(opts \\ []) do
    mutating_webhook_path =
      (opts[:mutating_webhook_path] || @mutating_webhook_path) |> String.split("/", trim: true)

    validating_webhook_path =
      (opts[:validating_webhook_path] || @validating_webhook_path)
      |> String.split("/", trim: true)

    quote do
      alias Bonny.AdmissionControl.Router

      import Router, only: [mutating: 2]

      @before_compile Router

      use Plug.Builder

      plug(Plug.Parsers,
        parsers: [:urlencoded, :json],
        json_decoder: Jason
      )

      plug(:process_request)

      @spec process_request(Plug.Conn.t(), any()) :: Plug.Conn.t()
      defp process_request(
             %Plug.Conn{method: "POST", path_info: unquote(mutating_webhook_path)} = conn,
             _
           ) do
        Bonny.AdmissionControl.Router.process_request(conn, &__MODULE__.process_mutating/1)
      end

      defp process_request(
             %Plug.Conn{method: "POST", path_info: unquote(validating_webhook_path)} = conn,
             _
           ) do
        Bonny.AdmissionControl.Router.process_request(conn, &__MODULE__.process_validating/1)
      end

      defp process_request(conn, _) do
        send_resp(conn, 404, "Not Found")
      end
    end
  end

  defmacro mutating(gvr, handler: handler) do
    quote do
      def process_mutating(
            %AdmissionReview{request: %{"resource" => unquote(gvr)}} = admission_review
          ) do
        unquote(handler).handle(admission_review)
      end
    end
  end

  defmacro validating(gvr, handler: handler) do
    quote do
      def process_validating(
            %AdmissionReview{request: %{"resource" => unquote(gvr)}} = admission_review
          ) do
        unquote(handler).handle(admission_review)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Fallbacks
      def process_mutating(%AdmissionReview{} = admission_review), do: admission_review
      def process_validating(%AdmissionReview{} = admission_review), do: admission_review
    end
  end

  def process_request(conn, callback) do
    conn.body_params
    |> AdmissionReview.new()
    |> AdmissionReview.allow()
    |> callback.()
    |> encode_response()
    |> send_response(conn)
  end

  defp send_response(response_body, conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response_body)
  end

  @spec encode_response(AdmissionReview.t()) :: binary()
  defp encode_response(admission_review) do
    %{"apiVersion" => @api_version, "kind" => @kind}
    |> Map.put("response", admission_review.response)
    |> Jason.encode!()
  end
end
