defmodule Bella.Server.Watcher.ResponseBuffer do
  @moduledoc """
  Buffers streaming responses from HTTPoison and returns kubernetes watch events as JSON

  `ResponseBuffer` implementation from [Kazan](https://github.com/obmarg/kazan)'s LineBuffer.
  """

  alias __MODULE__
  @type t :: %__MODULE__{lines: list(binary), pending: binary}
  defstruct lines: [], pending: ""

  @doc "Create a new `ResponseBuffer`"
  @spec new() :: __MODULE__.t()
  def new, do: %ResponseBuffer{}

  @doc "Add an HTTP response chunk to the buffer"
  @spec add_chunk(__MODULE__.t(), binary) :: __MODULE__.t()
  def add_chunk(%ResponseBuffer{lines: lines, pending: pending}, chunk) do
    {new_lines, pending} =
      case String.last(chunk) do
        # Final line is complete
        "\n" ->
          {String.split(pending <> String.trim_trailing(chunk), "\n"), ""}

        # Final line is not complete
        _ ->
          new_lines = String.split(pending <> chunk, "\n")
          {Enum.drop(new_lines, -1), List.last(new_lines)}
      end

    %ResponseBuffer{lines: lines ++ new_lines, pending: pending}
  end

  @doc """
  Returns complete lines of JSON from streaming HTTP Response.

  Lines are in NDJSON format; each line is a JSON object.
  """
  @spec get_lines(__MODULE__.t()) :: {list(binary), __MODULE__.t()}
  def get_lines(%ResponseBuffer{lines: lines} = buffer) do
    {lines, %ResponseBuffer{buffer | lines: []}}
  end
end
