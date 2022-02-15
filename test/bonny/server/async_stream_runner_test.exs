# credo:disable-for-this-file
defmodule Bonny.Server.AsyncStreamRunnerTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Bonny.Server.AsyncStreamRunner, as: MUT

  test "Runs the given stream in a separate process" do
    self = self()

    stream =
      Stream.iterate(0, &(&1 + 1))
      |> Stream.map(&send(self, "Current number: #{&1}"))
      |> Stream.take(5)

    {:ok, pid} = MUT.start_link(stream: stream)
    ref = Process.monitor(pid)

    assert_receive "Current number: 0"
    assert_receive "Current number: 1"
    assert_receive "Current number: 2"
    assert_receive "Current number: 3"
    assert_receive "Current number: 4"
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end
end
