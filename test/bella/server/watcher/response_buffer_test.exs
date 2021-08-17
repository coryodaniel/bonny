defmodule Bella.Server.Watcher.ResponseBufferTest do
  use ExUnit.Case
  alias Bella.Server.Watcher.ResponseBuffer

  test "get_lines with nothing" do
    {events, _buffer} =
      ResponseBuffer.new()
      |> ResponseBuffer.get_lines()

    assert [] == events
  end

  test "get_lines when adding one chunk" do
    {events, _buffer} =
      ResponseBuffer.new()
      |> ResponseBuffer.add_chunk("c1\n")
      |> ResponseBuffer.get_lines()

    assert ["c1"] == events
  end

  test "get_lines when adding multiple chunks" do
    {events, _buffer} =
      ResponseBuffer.new()
      |> ResponseBuffer.add_chunk("c1\nc2\n")
      |> ResponseBuffer.add_chunk("c3\nc4\n")
      |> ResponseBuffer.get_lines()

    assert ["c1", "c2", "c3", "c4"] == events
  end

  test "get_lines when adding incomplete chunks" do
    {events, _buffer} =
      ResponseBuffer.new()
      |> ResponseBuffer.add_chunk("c1\nc2\n")
      |> ResponseBuffer.add_chunk("c3\nc")
      |> ResponseBuffer.add_chunk("4\nc5\n")
      |> ResponseBuffer.get_lines()

    assert ["c1", "c2", "c3", "c4", "c5"] == events
  end

  test "get_lines when in middle of incomplete chunks" do
    {events, buffer} =
      ResponseBuffer.new()
      |> ResponseBuffer.add_chunk("c1\nc2\n")
      |> ResponseBuffer.add_chunk("c3\nc")
      |> ResponseBuffer.get_lines()

    assert ["c1", "c2", "c3"] == events

    {next_events, _buffer} =
      buffer
      |> ResponseBuffer.add_chunk("4\nc5\n")
      |> ResponseBuffer.get_lines()

    assert ["c4", "c5"] == next_events
  end

  test "Add empty chunk" do
    {events, _buffer} =
      ResponseBuffer.new()
      |> ResponseBuffer.add_chunk("c1\n")
      |> ResponseBuffer.add_chunk("")
      |> ResponseBuffer.get_lines()

    assert ["c1"] == events
  end

  test "Add just cr chunk" do
    {events, _buffer} =
      ResponseBuffer.new()
      |> ResponseBuffer.add_chunk("c1")
      |> ResponseBuffer.add_chunk("\n")
      |> ResponseBuffer.get_lines()

    assert ["c1"] == events
  end
end
