defmodule Bonny.AdmissionControl.WebhookPlug do
  @moduledoc """
  Plug that processes incoming admission webhook requests. Valid requests are forwarded to given webhook handlers.

  You have to specify the `:webhook_type` you want to forward to this plug. The `:webhook_type` has to be be either
  `:validating_webhook` or `:mutating_webhook`.

  ## Examples

  ### Compile time  configuration

  In a Phoenix router you would forward post requests to this plug:

      post "/admission-review/validate", Bonny.AdmissionControl.WebhookPlug,
        webhook_type: :validating_webhook,
        handlers: [MyApp.WebhookHandlers.FooResourceWebhookHandler]

      post "/admission-review/mutate", Bonny.AdmissionControl.WebhookPlug,
        webhook_type: :mutating_webhook,
        handlers: [MyApp.WebhookHandlers.BarResourceWebhookHandler]

  ### Runtime configuration

  In the example above, the handlers are defined at compile time. If you need to define the handlers at runtime, you
  can define them in `config/runtime.exs`. Note that in this case, handlers are global for all instances of the plug,
  unless declared at compile time like above.

  Your `config/runtime.exs`:

      import Config

      config :bonny_plug, Bonny.AdmissionControl.WebhookPlug
        handlers: [MyApp.WebhookHandlers.FooResourceWebhookHandler]

  Your `router.ex`:

      post "/admission-review/validate", Bonny.AdmissionControl.WebhookPlug,
        webhook_type: :validating_webhook
        # handlers set at compile time according to config

      post "/admission-review/mutate", Bonny.AdmissionControl.WebhookPlug,
        webhook_type: :mutating_webhook,
        handlers: [MyApp.WebhookHandlers.BarResourceWebhookHandler] # NOT overwritten at compile time!
  """

  import Plug.Conn

  alias Bonny.AdmissionControl.AdmissionReview
  alias Bonny.AdmissionControl.ReviewRequest

  @api_version "admission.k8s.io/v1"
  @kind "AdmissionReview"

  @type webhook_type :: :validating_webhook | :mutating_webhook

  def init(options) do
    Keyword.put_new_lazy(options, :handlers, fn ->
      Application.get_env(:bonny_plug, Bonny.AdmissionControl.WebhookPlug)[:handlers]
    end)
  end

  def call(%Plug.Conn{method: "POST"} = conn, opts) do
    webhook_type = Keyword.fetch!(opts, :webhook_type)
    handlers = Keyword.get(opts, :handlers, [])

    case process(conn.body_params, webhook_type, handlers) do
      {:ok, response_body} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, response_body)

      {:error, code, response_body} ->
        resp(conn, code, response_body)
    end
  end

  def call(conn, _), do: send_resp(conn, 404, "Not Found")

  @spec process(map(), atom(), Enum.t()) :: {:ok, binary()} | {:error, integer(), binary()}
  def process(
        %{"apiVersion" => @api_version, "kind" => @kind, "request" => request},
        webhook_type,
        handlers
      ) do
    response =
      request
      |> AdmissionReview.create()
      |> ReviewRequest.allow()
      |> (&Enum.reduce(handlers, &1, fn handler, acc ->
            Kernel.apply(handler, :process, [acc, webhook_type])
          end)).()
      |> Map.get(:response)

    response_body =
      Jason.encode!(%{"apiVersion" => @api_version, "kind" => @kind, "response" => response})

    {:ok, response_body}
  end

  def process(_, _, _),
    do:
      {:error, 400,
       "Unsupported Payload. This service expects a k8s admission review json document of apiVersion \"admission.k8s.io/v1\"."}
end
