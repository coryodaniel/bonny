defmodule Bonny.Watcher.ImplTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Bonny.Watcher.Impl

  setup do
    bypass = Bypass.open()
    # k8s_config = K8s.Conf.from_file("test/support/kubeconfig.yaml")
    # k8s_config = %{k8s_config | url: "http://localhost:#{bypass.port}/"}

    {:ok, bypass: bypass}
  end

  defmodule Whizbang do
    @moduledoc false
    def add(evt), do: emit(:added, evt)
    def modify(evt), do: emit(:modified, evt)
    def delete(evt), do: emit(:deleted, evt)

    defp emit(type, evt) do
      send(self(), {type, evt})
      :ok
    end
  end

  def added_chunk do
    "{\"type\":\"ADDED\",\"object\":{\"apiVersion\":\"example.com/v1\",\"kind\":\"Widget\",\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/last-applied-configuration\":\"{\\\"apiVersion\\\":\\\"example.com/v1\\\",\\\"kind\\\":\\\"Widget\\\",\\\"metadata\\\":{\\\"annotations\\\":{},\\\"name\\\":\\\"test-widget\\\",\\\"namespace\\\":\\\"default\\\"}}\\n\"},\"clusterName\":\"\",\"creationTimestamp\":\"2018-12-17T06:26:41Z\",\"generation\":1,\"name\":\"test-widget\",\"namespace\":\"default\",\"resourceVersion\":\"705460\",\"selfLink\":\"/apis/example.com/v1/namespaces/default/widgets/test-widget\",\"uid\":\"b7464e30-01c4-11e9-9066-025000000001\"}}}\n"
  end

  def deleted_chunk do
    "{\"type\":\"DELETED\",\"object\":{\"apiVersion\":\"example.com/v1\",\"kind\":\"Widget\",\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/last-applied-configuration\":\"{\\\"apiVersion\\\":\\\"example.com/v1\\\",\\\"kind\\\":\\\"Widget\\\",\\\"metadata\\\":{\\\"annotations\\\":{},\\\"name\\\":\\\"test-widget\\\",\\\"namespace\\\":\\\"default\\\"}}\\n\"},\"clusterName\":\"\",\"creationTimestamp\":\"2018-12-17T06:26:41Z\",\"generation\":1,\"name\":\"test-widget\",\"namespace\":\"default\",\"resourceVersion\":\"705464\",\"selfLink\":\"/apis/example.com/v1/namespaces/default/widgets/test-widget\",\"uid\":\"b7464e30-01c4-11e9-9066-025000000001\"}}}\n"
  end

  describe "new/1" do
    test "returns the default state" do
      assert %Impl{mod: Widget, spec: %Bonny.CRD{}, cluster_name: :test} = Impl.new(Widget)
    end
  end

  describe "watch_for_changes/2" do
    test "returns changes to a CRD resource", %{bypass: bypass} do
      added = added_chunk()
      deleted = deleted_chunk()

      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/apis/example.com/v1/namespaces/default/widgets"
        assert conn.query_string == "resourceVersion=1337&watch=true"

        conn = Plug.Conn.send_chunked(conn, 200)
        {:ok, conn} = Plug.Conn.chunk(conn, added)
        {:ok, conn} = Plug.Conn.chunk(conn, deleted)
        conn
      end)

      state = Impl.new(Widget)
      state = %{state | cluster_name: :test}
      state = %{state | resource_version: "1337"}

      Impl.watch_for_changes(state, self())

      assert_receive %HTTPoison.AsyncStatus{code: 200}, 1_000
      assert_receive %HTTPoison.AsyncHeaders{}, 1_000
      assert_receive %HTTPoison.AsyncChunk{chunk: ^added}, 1_000
      assert_receive %HTTPoison.AsyncChunk{chunk: ^deleted}, 1_000
      assert_receive %HTTPoison.AsyncEnd{}, 1_000
    end
  end

  describe "parse_chunk/1" do
    test "strips whitespace and parses json" do
      result = added_chunk() |> Impl.parse_chunk()
      assert %{"type" => "ADDED"} = result
    end
  end

  describe "dispatch/2" do
    test "dispatches a kubernetes API event to the given module" do
      added_event = added_chunk() |> Impl.parse_chunk()
      Impl.dispatch(added_event, Whizbang)
      assert_received({:added, added_event})
    end
  end
end
