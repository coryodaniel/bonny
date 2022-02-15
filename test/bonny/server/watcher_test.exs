# credo:disable-for-this-file
defmodule Bonny.Server.WatcherTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Bonny.Server.Watcher, as: MUT

  defmodule K8sMock do
    require Logger

    import K8s.Test.HTTPHelper

    def conn(), do: Bonny.K8sMock.conn(__MODULE__)

    def request(:get, "apis/example.com/v1/widgets", _body, _headers, opts) do
      case get_in(opts, [:params, :watch]) do
        true ->
          pid = Keyword.fetch!(opts, :stream_to)

          send_object(pid, %{
            "type" => "ADDED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Namespace",
              "metadata" => %{"name" => "foo", "resourceVersion" => "11"}
            }
          })

          send_object(pid, %{
            "type" => "ADDED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Namespace",
              "metadata" => %{"name" => "bar", "resourceVersion" => "12"}
            }
          })

          send_object(pid, %{
            "type" => "MODIFIED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Namespace",
              "metadata" => %{"name" => "foo", "resourceVersion" => "13"}
            }
          })

          send_object(pid, %{
            "type" => "DELETED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Namespace",
              "metadata" => %{"name" => "foo", "resourceVersion" => "14"}
            }
          })

          {:ok, %HTTPoison.AsyncResponse{id: make_ref()}}

        nil ->
          render(%{"metadata" => %{"resourceVersion" => "10"}})
      end
    end

    def request(_method, _url, _body, _headers, _opts) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %HTTPoison.Error{reason: "request not mocked"}}
    end
  end

  defmodule TestController do
    @behaviour MUT

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

    operation = K8s.Client.list("example.com/v1", :widgets)
    stream = MUT.get_stream(__MODULE__.TestController, conn, operation) |> Stream.take(4)

    Task.async(fn ->
      Stream.run(stream)
    end)
    |> Task.await()

    assert_received {:add, "foo"}
    assert_received {:add, "bar"}
    assert_received {:modify, "foo"}
    assert_received {:delete, "foo"}
  end
end
