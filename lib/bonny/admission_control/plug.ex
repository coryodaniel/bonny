defmodule Bonny.AdmissionControl.Plug do
  use Plug.Builder

  alias Bonny.AdmissionControl.AdmissionReview

  require Logger

  @api_version "admission.k8s.io/v1"
  @kind "AdmissionReview"

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: Jason
  )

  @impl true
  def init(opts) do
    if opts[:webhook_type] not in [:mutating, :validating] do
      raise(CompileError,
        file: __ENV__.file,
        line: __ENV__.line,
        description:
          "#{__MODULE__} requires you to define the :webhook_type option as :mutating or :validating when plugged."
      )
    end

    webhook_handler =
      case opts[:webhook_handler] do
        {module, init_opts} ->
          {module, module.init(init_opts)}

        nil ->
          raise(CompileError,
            file: __ENV__.file,
            line: __ENV__.line,
            description: "#{__MODULE__} requires you to set the :webhook_handler option."
          )

        module ->
          {module, []}
      end

    %{
      webhook_type: opts[:webhook_type],
      webhook_handler: webhook_handler
    }
  end

  @doc false
  @impl true
  def call(conn, webhook_config) do
    %{
      webhook_type: webhook_type,
      webhook_handler: {webhook_handler, opts}
    } = webhook_config

    conn
    |> super([])
    |> Map.get(:body_params)
    |> AdmissionReview.new(webhook_type)
    |> tap(fn review ->
      Logger.debug("Processing Admission Review Request", library: :bonny, review: review)
    end)
    |> AdmissionReview.allow()
    |> webhook_handler.call(opts)
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
