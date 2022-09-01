# credo:disable-for-this-file
defmodule Bonny.Server.AsyncStreamRunnerTest do
  @moduledoc false
  use ExUnit.Case, async: false

  @msg_timeout 500

  alias Bonny.Server.AsyncStreamRunner, as: MUT

  test "Runs the given stream in a separate process" do
    self = self()
    ref = make_ref()

    stream =
      Stream.iterate(0, &(&1 + 1))
      |> Stream.map(&send(self, {ref, "Current number: #{&1}"}))
      |> Stream.take(5)

    {:ok, pid} = MUT.start_link(stream: stream)
    monitor_ref = Process.monitor(pid)

    assert_receive({^ref, "Current number: 0"}, @msg_timeout)
    assert_receive({^ref, "Current number: 1"}, @msg_timeout)
    assert_receive({^ref, "Current number: 2"}, @msg_timeout)
    assert_receive({^ref, "Current number: 3"}, @msg_timeout)
    assert_receive({^ref, "Current number: 4"}, @msg_timeout)
    assert_receive({:DOWN, ^monitor_ref, :process, _, :normal}, @msg_timeout)
  end
end
