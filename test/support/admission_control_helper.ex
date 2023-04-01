defmodule Bonny.Test.AdmissionControlHelper do
  use Plug.Test

  def webhook_request_conn() do
    body = """
    {
      "apiVersion": "admission.k8s.io/v1",
      "kind": "AdmissionReview",
      "request": {
        "uid": "705ab4f5-6393-11e8-b7cc-42010a800002",
        "kind": {
          "group": "example.com",
          "version": "v1alpha1",
          "kind": "SomeCRD"
        },
        "resource": {
          "group": "example.com",
          "version": "v1alpha1",
          "resource": "somecrds"
        },
        "requestKind": {
          "group": "example.com",
          "version": "v1alpha1",
          "kind": "SomeCRD"
        },
        "requestResource": {
          "group": "example.com",
          "version": "v1alpha1",
          "resource": "somecrds"
        },
        "name": "my-deployment",
        "namespace": "my-namespace",
        "operation": "UPDATE",
        "userInfo": {
          "username": "admin",
          "uid": "014fbff9a07c",
          "groups": [
            "system:authenticated",
            "my-admin-group"
          ],
          "extra": {
            "some-key": [
              "some-value1",
              "some-value2"
            ]
          }
        },
        "object": {
          "apiVersion": "autoscaling/v1",
          "kind": "Scale"
        },
        "oldObject": {
          "apiVersion": "autoscaling/v1",
          "kind": "Scale"
        },
        "options": {
          "apiVersion": "meta.k8s.io/v1",
          "kind": "UpdateOptions"
        },
        "dryRun": false
      }
    }
    """

    conn("POST", "/webhook", body)
    |> put_req_header("content-type", "application/json")
  end
end
