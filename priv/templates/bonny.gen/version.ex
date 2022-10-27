defmodule <%= @app_name %>.API.<%= @version %>.<%= @name %> do
  @moduledoc """
  <%= @app_name %>: <%= @name %> CRD <%= @version %> version.

  Modify the `manifest/0` function in order to override the defaults,
  e.g. to define an openAPIV3 schema, add subresources or additional
  printer columns:

  ```
  def manifest() do
    struct!(
      defaults(),
      name: "<%= String.downcase(@version) %>",
      schema: %{
        openAPIV3Schema: %{
          type: :object,
          properties: %{
            spec: %{
              type: :object,
              properties: %{
                foos: %{type: :integer}
              }
            },
            status: %{
              ...
            }
          }
        }
      },
      additionalPrinterColumns: [
        %{name: "foos", type: :integer, description: "Number of foos", jsonPath: ".spec.foos"}
      ],
      subresources: %{
        status: %{}
      }
    )
  end
  ```
  """
  use Bonny.API.Version,
    hub: true

  @impl true
  def manifest() do
    defaults()
    |> struct!(name: "<%= String.downcase(@version) %>")
    |> add_observed_generation_status()
  end
end
