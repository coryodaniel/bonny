defmodule Bonny.AdmissionControl.WebhookRouter do
  import Plug.Conn

  alias Bonny.AdmissionControl.AdmissionReview

  require Logger

  @api_version "admission.k8s.io/v1"
  @kind "AdmissionReview"

  @callback process(AdmissionReview.t()) :: AdmissionReview.t()

  defmacro __using__(_opts) do
    quote do
      use Plug.Builder

      alias Bonny.AdmissionControl.WebhookRouter

      @behaviour WebhookRouter

      plug(Plug.Parsers,
        parsers: [:urlencoded, :json],
        json_decoder: Jason
      )

      def init(opts) do
        WebhookRouter.plug_init(opts, __MODULE__)
      end

      def call(%Plug.Conn{} = conn, webhook_type) do
        conn
        |> super([])
        |> WebhookRouter.process_request(__MODULE__, webhook_type)
      end
    end
  end

  @doc false
  def plug_init(opts, module) do
    if opts[:webhook_type] not in [:mutating, :validating] do
      raise(CompileError,
        file: __ENV__.file,
        line: __ENV__.line,
        description:
          "#{module} requires you to define the :webhook_type as :mutating or :validating when plugged."
      )
    end

    opts[:webhook_type]
  end

  @doc false
  def process_request(conn, router, webhook_type) do
    conn.body_params
    |> AdmissionReview.new(webhook_type)
    |> tap(fn review ->
      Logger.debug("Processing Admission Review Request", library: :bonny, review: review)
    end)
    |> AdmissionReview.allow()
    |> router.process()
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
