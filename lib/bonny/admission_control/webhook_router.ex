defmodule Bonny.AdmissionControl.WebhookRouter do
  import Plug.Conn

  alias Bonny.AdmissionControl.AdmissionReview

  require Logger

  @api_version "admission.k8s.io/v1"
  @kind "AdmissionReview"

  @callback process_mutating_review(AdmissionReview.t()) :: AdmissionReview.t()
  @callback process_validating_review(AdmissionReview.t()) :: AdmissionReview.t()
  @optional_callbacks process_validating_review: 1, process_mutating_review: 1

  defmacro __using__(_opts) do
    quote do
      use Plug.Builder

      alias Bonny.AdmissionControl.WebhookRouter

      @behaviour WebhookRouter

      plug(Plug.Parsers,
        parsers: [:urlencoded, :json],
        json_decoder: Jason
      )

      @impl true
      def init(opts) do
        WebhookRouter.plug_init(opts, __MODULE__)
      end

      @impl true
      def call(conn, callback) do
        conn
        |> super([])
        |> WebhookRouter.process_request(&apply(__MODULE__, callback, [&1]))
      end
    end
  end

  @doc false
  def plug_init(opts, module) do
    case Keyword.fetch(opts, :webhook_type) do
      :error ->
        raise(CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: "#{module} requires you to define the :webhook_type option when plugged."
        )

      {:ok, :mutating} ->
        if not function_exported?(module, :process_mutating_review, 1) do
          raise(CompileError,
            file: __ENV__.file,
            line: __ENV__.line,
            description:
              "process_mutating_review/1 must be defined if using with webhook_type: :mutating."
          )
        end

        :process_mutating_review

      {:ok, :validating} ->
        if not function_exported?(module, :process_validating_review, 1) do
          raise(CompileError,
            file: __ENV__.file,
            line: __ENV__.line,
            description:
              "process_validating_review/1 must be defined if using with webhook_type: :validating."
          )
        end

        :process_validating_review
    end
  end

  @doc false
  def process_request(conn, callback) do
    conn.body_params
    |> AdmissionReview.new()
    |> tap(fn review ->
      Logger.debug("Processing Admission Review Request", library: :bonny, review: review)
    end)
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
