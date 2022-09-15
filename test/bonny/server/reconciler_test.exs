# credo:disable-for-this-file
defmodule Bonny.Server.ReconcilerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Bonny.Server.Reconciler, as: MUT

  defmodule K8sMock do
    import K8s.Test.HTTPHelper

    def conn(), do: Bonny.K8sMock.conn(__MODULE__)

    def request(:get, "apis/example.com/v1/foos", _, _, opts) do
      limit = get_in(opts, [:params, :limit])

      case limit do
        10 -> render(%{"items" => [%{"name" => "foo"}, %{"name" => "bar"}]})
        1 -> render(%{"metadata" => %{"resourceVersion" => "1337"}})
      end
    end

    def request(:get, "apis/example.com/v1/cogs", _, _, _) do
      render(%{"reason" => "NotFound", "message" => "next page not found"}, 404, [
        {"Content-Type", "application/json"}
      ])
    end
  end

  defmodule TestController do
    @behaviour MUT

    def reconcile(resource) do
      # Process runing test was registered under the name of its module
      send(Bonny.Server.ReconcilerTest, {:name, resource["name"]})

      :ok
    end
  end

  setup do
    [conn: __MODULE__.K8sMock.conn()]
  end

  test "reconciler returns a prepared stream that calls the reconcile function when run", %{
    conn: conn
  } do
    Process.register(self(), __MODULE__)

    operation = K8s.Client.list("example.com/v1", :foos)
    MUT.get_stream(TestController, conn, operation) |> Stream.run()

    assert_receive {:name, "foo"}
    assert_receive {:name, "bar"}
  end

  test "reconciler logs and rejects fetch errors", %{conn: conn} do
    operation = K8s.Client.list("example.com/v1", :cogs)

    log =
      capture_log(fn ->
        level_before_test = Logger.level()
        Logger.configure(level: :debug)
        events = MUT.get_stream(TestController, conn, operation) |> Enum.to_list()
        #  assert event is rejected
        assert Enum.empty?(events)
        Logger.configure(level: level_before_test)
      end)

    # assert error is logged
    assert log =~ "Reconciler fetch failed"
  end
end
