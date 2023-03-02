defmodule Bonny.AdmissionControl.AdmissionReview do
  @moduledoc """
  Internal representation of an admission review.
  """

  require Logger

  @type t :: %__MODULE__{
          request: map(),
          response: map()
        }

  @fields [
    :request,
    :response
  ]

  @enforce_keys @fields
  defstruct @fields

  def create(request) do
    %__MODULE__{
      request: request,
      response: %{
        "uid" => request["uid"]
      }
    }
  end
end
