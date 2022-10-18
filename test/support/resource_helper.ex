defmodule Bonny.Test.ResourceHelper do
  @moduledoc false

  def to_string(pid) when is_pid(pid), do: pid_to_string(pid)
  def to_string(ref) when is_reference(ref), do: ref_to_string(ref)

  @spec ref_to_string(reference()) :: binary()
  def ref_to_string(ref), do: ref |> :erlang.ref_to_list() |> List.to_string()

  @spec pid_to_string(pid()) :: binary()
  def pid_to_string(pid), do: pid |> :erlang.pid_to_list() |> List.to_string()

  @spec string_to_ref(binary()) :: reference()
  def string_to_ref(ref), do: ref |> String.to_charlist() |> :erlang.list_to_ref()

  @spec string_to_pid(binary()) :: pid()
  def string_to_pid(pid), do: pid |> String.to_charlist() |> :erlang.list_to_pid()
end
