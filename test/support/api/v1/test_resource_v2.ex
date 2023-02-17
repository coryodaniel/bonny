defmodule Bonny.Test.API.V1.TestResourceV2 do
  @moduledoc false
  use Bonny.API.Version

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
              },
              required: ["pid", "ref"]
            },
            status: %{
              type: :object,
              properties: %{
                foo: %{type: :string}
              }
            }
          }
        }
      }
    )
    |> add_observed_generation_status()
    |> add_conditions()
  end
end
