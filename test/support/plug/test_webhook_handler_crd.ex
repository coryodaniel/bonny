defmodule Bonny.Test.Plug.WebhookHandlerCRD do
  def handle(admission_review) do
    Map.update!(admission_review, :response, &Map.put(&1, "allowed", false))
  end
end
