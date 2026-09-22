defmodule Bonny.Operator.LeaderElectorTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Bonny.Operator.LeaderElector

  defmodule K8sMock do
    def request(:get, _uri, _body, _headers, _opts) do
      {:error,
       %K8s.Client.APIError{
         message: "etcdserver: leader changed",
         reason: "InternalError"
       }}
    end
  end

  test "keeps running when the lease lookup returns a Kubernetes API error" do
    previous_level = Logger.level()
    Logger.configure(level: :warning)

    on_exit(fn -> Logger.configure(level: previous_level) end)

    conn = Bonny.K8sMock.conn(K8sMock)

    log =
      capture_log([level: :warning], fn ->
        {:ok, pid} = LeaderElector.start_link([], __MODULE__, conn: conn)

        # The state request is sent after the initial election message, ensuring
        # that the lease lookup has completed before checking the process.
        :sys.get_state(pid)
        assert Process.alive?(pid)

        GenServer.stop(pid)
      end)

    assert log =~ "{Operator=Bonny.Operator.LeaderElectorTest}"
    assert log =~ "Kubernetes API error while getting the lease"
    assert log =~ "etcdserver: leader changed"
  end
end
