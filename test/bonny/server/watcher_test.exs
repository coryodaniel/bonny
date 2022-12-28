# credo:disable-for-this-file
defmodule Bonny.Server.WatcherTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Bonny.Server.Watcher, as: MUT

  defmodule K8sMock do
    require Logger

    alias K8s.Client.HTTPTestHelper

    def conn(), do: Bonny.K8sMock.conn(__MODULE__)

    def request(:get, %URI{path: "apis/example.com/v1/widgets"}, _body, _headers, _opts) do
      HTTPTestHelper.render(%{"metadata" => %{"resourceVersion" => "10"}})
    end

    def request(_method, _uri, _body, _headers, _opts) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %K8s.Client.HTTPError{message: "request not mocked"}}
    end

    def stream(:get, %URI{path: "apis/example.com/v1/widgets"}, _body, _headers, _opts) do
      {:ok,
       [
         HTTPTestHelper.stream_object(%{
           "type" => "ADDED",
           "object" => %{
             "apiVersion" => "v1",
             "kind" => "Namespace",
             "metadata" => %{"name" => "foo", "resourceVersion" => "11", "generation" => 1}
           }
         }),
         HTTPTestHelper.stream_object(%{
           "type" => "MODIFIED",
           "object" => %{
             "apiVersion" => "v1",
             "kind" => "Namespace",
             "metadata" => %{"name" => "bar", "resourceVersion" => "12", "generation" => 2},
             "status" => %{"observedGeneration" => 1}
           }
         }),
         HTTPTestHelper.stream_object(%{
           "type" => "MODIFIED",
           "object" => %{
             "apiVersion" => "v1",
             "kind" => "Namespace",
             "metadata" => %{"name" => "foo", "resourceVersion" => "13", "generation" => 2},
             "status" => %{"observedGeneration" => 2}
           }
         }),
         HTTPTestHelper.stream_object(%{
           "type" => "DELETED",
           "object" => %{
             "apiVersion" => "v1",
             "kind" => "Namespace",
             "metadata" => %{"name" => "foo", "resourceVersion" => "14", "generation" => 2},
             "status" => %{"observedGeneration" => 2}
           }
         })
       ]}
    end
  end

  defmodule TestController do
    def add(resource) do
      # Process runing test was registered under the name of its module
      send(Bonny.Server.WatcherTest, {:add, resource["metadata"]["name"]})
      :ok
    end

    def modify(resource) do
      # Process runing test was registered under the name of its module
      send(Bonny.Server.WatcherTest, {:modify, resource["metadata"]["name"]})
      :ok
    end

    def delete(resource) do
      # Process runing test was registered under the name of its module
      send(Bonny.Server.WatcherTest, {:delete, resource["metadata"]["name"]})
      :ok
    end
  end

  setup do
    [conn: __MODULE__.K8sMock.conn()]
  end

  test "watcher returns a prepared stream that calls the add/modify/delete functions for each event",
       %{conn: conn} do
    Process.register(self(), __MODULE__)

    operation = K8s.Client.watch("example.com/v1", :widgets)
    stream = MUT.get_stream(__MODULE__.TestController, conn, operation) |> Stream.take(4)

    Task.async(fn ->
      Stream.run(stream)
    end)
    |> Task.await()

    assert_received {:add, "foo"}
    assert_received {:modify, "bar"}
    assert_received {:modify, "foo"}
    assert_received {:delete, "foo"}
  end
end
