defmodule Bonny.Test.Plug.WebhookHandlerCRDV1Beta1 do
  def handle(admission_review) do
    Map.update!(admission_review, :response, &Map.put(&1, "allowed", false))
  end
end
