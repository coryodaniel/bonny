defmodule Bonny.AdmissionControl.WebhookHandler do
  @moduledoc """
  This module dispatches the admission webhook requests to the handlers. You can `use` this module in your webhook
  handler to connect it to the Plug.

  ## Options

  When `use`-ing this module, you have to tell it about the resource you want to act upon:

  ### Custom Resource Definition

  * `crd` - If you have a CRD YAML file, just pass the path to the file as option `crd`. The `WebhookHandler` will extract the required values from the file.

  ### Explicit Resource Specification

  The `WebhookHandler` needs to know the following values from the resource you want to act upon:

  * `group` - The group of the resource, e.g. `"apps"`
  * `plural` - The plural name of the resource, e.g. `"deployments"`
  * `api_versions` - A list of versions of the resource, e.g. `["v1beta1", "v1"]`

  ## Functions to be implemented in your Webhook Handler

  Your webhook handler should implement at least one of the two functions `validating_webhook/1` and
  `mutating_webhook/1`. These are going to be called by this module depending on whether the incoming request is of
  type `:validating_webhook` or `:mutating_webhook` according to the `Bonny.AdmissionControl.WebhookPlug` configuration.

  ## Examples

  ```
  defmodule FooAdmissionWebhookHandler do
    use Bonny.AdmissionControl.WebhookHandler, crd: "manifest/src/crds/foo.crd.yaml"

    @impl true
    def validating_webhook(admission_review)  do
      check_immutable(admission_review, ["spec", "someField"])
    end

    @impl true
    def mutating_webhook(admission_review)  do
      allow(admission_review)
    end
  end
  ```

  ```
  defmodule BarAdmissionWebhookHandler do
    use Bonny.AdmissionControl.WebhookHandler,
      group: "my.operator.com",
      resource: "barresources",
      api_versions: ["v1"]

    @impl true
    def validating_webhook(admission_review)  do
      check_immutable(admission_review, ["spec", "someField"])
    end

    @impl true
    def mutating_webhook(admission_review)  do
      deny(admission_review)
    end
  end
  ```
  """

  require Logger

  alias Bonny.AdmissionControl.{AdmissionReview, WebhookPlug}

  @callback process(AdmissionReview.t(), WebhookPlug.webhook_type()) :: AdmissionReview.t()
  @callback mutating_webhook(AdmissionReview.t()) :: AdmissionReview.t()
  @callback validating_webhook(AdmissionReview.t()) :: AdmissionReview.t()
  @optional_callbacks mutating_webhook: 1, validating_webhook: 1

  @type webhook_type :: :mutating_webhook | :validating_webhook

  defmacro __using__(opts) do
    if is_nil(opts[:crd]) do
      raise CompileError,
        line: __ENV__.line,
        file: __ENV__.file,
        description:
          "You have to pass the :crd option when using Bonny.AdmissionControl.WebhookHandler"
    end

    group = quote do: unquote(opts)[:crd].group
    plural = quote do: unquote(opts)[:crd].names.plural
    api_versions = quote do: Enum.map(unquote(opts)[:crd].versions, & &1.manifest().name)

    quote do
      import Bonny.AdmissionControl.ReviewRequest

      @behaviour Bonny.AdmissionControl.WebhookHandler

      @group unquote(group)
      @plural unquote(plural)
      @api_versions unquote(api_versions)

      @impl true
      @spec process(AdmissionReview.t(), WebhookPlug.webhook_type()) :: AdmissionReview.t()
      def process(
            %AdmissionReview{
              request: %{
                "resource" => %{"group" => @group, "version" => version, "resource" => @plural}
              }
            } = admission_review,
            webhook_type
          )
          when webhook_type in [:validating_webhook, :mutating_webhook] and
                 version in @api_versions do
        if function_exported?(__MODULE__, webhook_type, 1) do
          Kernel.apply(__MODULE__, webhook_type, [admission_review])
        else
          admission_review
        end
      end

      def process(admission_review, _), do: admission_review
    end
  end
end
