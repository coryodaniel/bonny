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

  def new(%{"kind" => "AdmissionReview", "request" => request}) do
    struct!(__MODULE__,
      request: request,
      response: %{"uid" => request["uid"]}
    )
  end

  @doc """
  Responds by allowing the operation

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.allow(admission_review)
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"allowed" => true}}
  """
  @spec allow(t()) :: t()
  def allow(admission_review) do
    put_in(admission_review.response["allowed"], true)
  end

  @doc """
  Responds by denying the operation

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.deny(admission_review)
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"allowed" => false}}
  """
  @spec deny(t()) :: t()
  def deny(admission_review) do
    put_in(admission_review.response["allowed"], false)
  end

  @doc """
  Responds by denying the operation, returning response code and message

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.deny(admission_review, 403, "foo")
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"allowed" => false, "status" => %{"code" => 403, "message" => "foo"}}}

      iex> Bonny.AdmissionControl.ReviewRequest.deny(%Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}}, "foo")
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"allowed" => false, "status" => %{"code" => 400, "message" => "foo"}}}
  """
  @spec deny(t(), integer(), binary()) :: t()
  @spec deny(t(), binary()) :: t()
  def deny(admission_review, code \\ 400, message) do
    admission_review
    |> deny()
    |> put_in([Access.key(:response), "status"], %{"code" => code, "message" => message})
  end

  @doc """
  Adds a warning to the admission review's response.

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.add_warning(admission_review, "warning")
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"warnings" => ["warning"]}}

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"warnings" => ["existing_warning"]}}
      ...> Bonny.AdmissionControl.ReviewRequest.add_warning(admission_review, "new_warning")
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"warnings" => ["new_warning", "existing_warning"]}}
  """
  @spec add_warning(t(), binary()) :: t()
  def add_warning(admission_review, warning) do
    update_in(
      admission_review,
      [Access.key(:response), Access.key("warnings", [])],
      &[warning | &1]
    )
  end

  @doc """
  Verifies that a given field has not been mutated.

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"spec" => %{"immutable" => "value"}}, "oldObject" => %{"spec" => %{"immutable" => "value"}}}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.check_immutable(admission_review, ["spec", "immutable"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"spec" => %{"immutable" => "value"}}, "oldObject" => %{"spec" => %{"immutable" => "value"}}}, response: %{}}

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"spec" => %{"immutable" => "new_value"}}, "oldObject" => %{"spec" => %{"immutable" => "value"}}}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.check_immutable(admission_review, ["spec", "immutable"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"spec" => %{"immutable" => "new_value"}}, "oldObject" => %{"spec" => %{"immutable" => "value"}}}, response: %{"allowed" => false, "status" => %{"code" => 400, "message" => "The field .spec.immutable is immutable."}}}
  """
  @spec check_immutable(t(), list()) :: t()
  def check_immutable(admission_review, field) do
    new_value = get_in(admission_review.request, ["object" | field])
    old_value = get_in(admission_review.request, ["oldObject" | field])

    if new_value == old_value,
      do: admission_review,
      else: deny(admission_review, "The field .#{Enum.join(field, ".")} is immutable.")
  end

  @doc """
  Checks the given field's value - if defined - against a list of allowed values. If the field is not defined, the
  request is considered valid and no error is returned. Use the CRD to define required fields.

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{"annotations" => %{"some/annotation" => "bar"}}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.check_allowed_values(admission_review, ~w(metadata annotations some/annotation), ["foo", "bar"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{"annotations" => %{"some/annotation" => "bar"}}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}}

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.check_allowed_values(admission_review, ~w(metadata annotations some/annotation), ["foo", "bar"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}}

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{"annotations" => %{"some/annotation" => "other"}}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}}
      ...> Bonny.AdmissionControl.ReviewRequest.check_allowed_values(admission_review, ~w(metadata annotations some/annotation), ["foo", "bar"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{"annotations" => %{"some/annotation" => "other"}}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{"allowed" => false, "status" => %{"code" => 400, "message" => ~S(The field .metadata.annotations.some/annotation must contain one of the values in ["foo", "bar"] but it's currently set to "other".)}}}
  """
  @spec check_allowed_values(t(), list(), list()) :: t()
  def check_allowed_values(admission_review, field, allowed_values) do
    value = get_in(admission_review.request, ["object" | field])

    if is_nil(value) or value in allowed_values,
      do: admission_review,
      else:
        deny(
          admission_review,
          "The field .metadata.annotations.some/annotation must contain one of the values in #{inspect(allowed_values)} but it's currently set to #{inspect(value)}."
        )
  end
end
