defmodule Bonny.Test.API.V1.TestResourceV3 do
  @moduledoc false
  use Bonny.API.Version,
    hub: true

  @impl true
  def manifest() do
    struct!(
      defaults(),
      schema: %{
        openAPIV3Schema: %{
          type: :object,
          properties: %{
            spec: %{
              type: :object,
              properties: %{
                pid: %{type: :string},
                ref: %{type: :string},
                rand: %{type: :string}
              }
            },
            status: %{
              type: :object,
              properties: %{
                rand: %{type: :string}
              }
            }
          }
        }
      },
      subresources: %{status: %{}}
    )
  end
end
