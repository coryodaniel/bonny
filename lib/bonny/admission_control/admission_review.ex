defmodule Bonny.AdmissionControl.AdmissionReview do
  @moduledoc """
  Internal representation of an admission review.
  """

  require Logger

  @derive Pluggable.Token

  @type webhook_type :: :mutating | :validating
  @type t :: %__MODULE__{
          request: map(),
          response: map(),
          webhook_type: webhook_type(),
          halted: boolean(),
          assigns: map()
        }

  @enforce_keys [:request, :response, :webhook_type]
  defstruct [:request, :response, :webhook_type, halted: false, assigns: %{}]

  def new(%{"kind" => "AdmissionReview", "request" => request}, webhook_type) do
    struct!(__MODULE__,
      request: request,
      response: %{"uid" => request["uid"]},
      webhook_type: webhook_type
    )
  end

  @doc """
  Responds by allowing the operation

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.allow(admission_review)
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"allowed" => true}, webhook_type: :validating}
  """
  @spec allow(t()) :: t()
  def allow(admission_review) do
    put_in(admission_review.response["allowed"], true)
  end

  @doc """
  Responds by denying the operation

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.deny(admission_review)
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"allowed" => false}, webhook_type: :validating}
  """
  @spec deny(t()) :: t()
  def deny(admission_review) do
    put_in(admission_review.response["allowed"], false)
  end

  @doc """
  Responds by denying the operation, returning response code and message

  ## Examples

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.deny(admission_review, 403, "foo")
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"allowed" => false, "status" => %{"code" => 403, "message" => "foo"}}, webhook_type: :validating}

      iex> Bonny.AdmissionControl.AdmissionReview.deny(%Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}, webhook_type: :validating}, "foo")
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"allowed" => false, "status" => %{"code" => 400, "message" => "foo"}}, webhook_type: :validating}
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

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.add_warning(admission_review, "warning")
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"warnings" => ["warning"]}, webhook_type: :validating}

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"warnings" => ["existing_warning"]}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.add_warning(admission_review, "new_warning")
      %Bonny.AdmissionControl.AdmissionReview{request: %{}, response: %{"warnings" => ["new_warning", "existing_warning"]}, webhook_type: :validating}
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

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"spec" => %{"immutable" => "value"}}, "oldObject" => %{"spec" => %{"immutable" => "value"}}}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.check_immutable(admission_review, ["spec", "immutable"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"spec" => %{"immutable" => "value"}}, "oldObject" => %{"spec" => %{"immutable" => "value"}}}, response: %{}, webhook_type: :validating}

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"spec" => %{"immutable" => "new_value"}}, "oldObject" => %{"spec" => %{"immutable" => "value"}}}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.check_immutable(admission_review, ["spec", "immutable"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"spec" => %{"immutable" => "new_value"}}, "oldObject" => %{"spec" => %{"immutable" => "value"}}}, response: %{"allowed" => false, "status" => %{"code" => 400, "message" => "The field .spec.immutable is immutable."}}, webhook_type: :validating}
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

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{"annotations" => %{"some/annotation" => "bar"}}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.check_allowed_values(admission_review, ~w(metadata annotations some/annotation), ["foo", "bar"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{"annotations" => %{"some/annotation" => "bar"}}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}, webhook_type: :validating}

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.check_allowed_values(admission_review, ~w(metadata annotations some/annotation), ["foo", "bar"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}, webhook_type: :validating}

      iex> admission_review = %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{"annotations" => %{"some/annotation" => "other"}}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{}, webhook_type: :validating}
      ...> Bonny.AdmissionControl.AdmissionReview.check_allowed_values(admission_review, ~w(metadata annotations some/annotation), ["foo", "bar"])
      %Bonny.AdmissionControl.AdmissionReview{request: %{"object" => %{"metadata" => %{"annotations" => %{"some/annotation" => "other"}}, "spec" => %{}}, "oldObject" => %{"spec" => %{}}}, response: %{"allowed" => false, "status" => %{"code" => 400, "message" => ~S(The field .metadata.annotations.some/annotation must contain one of the values in ["foo", "bar"] but it's currently set to "other".)}}, webhook_type: :validating}
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
