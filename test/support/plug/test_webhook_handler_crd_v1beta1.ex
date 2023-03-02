defmodule Bonny.Test.Plug.WebhookHandlerCRDV1Beta1 do
  use Bonny.AdmissionControl.WebhookHandler,
    crd: %Bonny.API.CRD{
      group: "example.com",
      scope: :Namespaced,
      names: Bonny.API.CRD.kind_to_names("TestResourceV2"),
      versions: [Bonny.Test.API.V1.TestResourceV2]
    }

  @spec validating_webhook(Bonny.AdmissionControl.AdmissionReview.t()) ::
          Bonny.AdmissionControl.AdmissionReview.t()
  @impl true
  def validating_webhook(admission_review) do
    Map.update!(admission_review, :response, &Map.put(&1, "allowed", false))
  end
end
