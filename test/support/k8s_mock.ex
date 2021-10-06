# credo:disable-for-this-file
defmodule Bonny.K8sMock do
  @behaviour K8s.Client.Provider
  require Logger

  def conn() do
    #  Have to register the mock here because Bonny uses Task.start() so we won't know the pid when starting the test.
    K8s.Client.DynamicHTTPProvider.register(self(), __MODULE__)

    %K8s.Conn{
      discovery_driver: K8s.Discovery.Driver.File,
      discovery_opts: [config: "test/support/discovery/tests.json"],
      http_provider: K8s.Client.DynamicHTTPProvider
    }
  end

  defp resp(%{} = resource) do
    body = Jason.encode!(resource)
    {:ok, %HTTPoison.Response{status_code: 200, body: body}}
  end

  @impl K8s.Client.Provider
  def request(:get, "apis/example.com/v1/foos", _, _, opts) do
    limit = get_in(opts, [:params, :limit])

    case limit do
      10 -> resp(%{"items" => [%{"name" => "foo"}, %{"name" => "bar"}]})
      1 -> resp(%{"metadata" => %{"resourceVersion" => "1337"}})
    end
  end

  def request(:get, "apis/example.com/v1/errors", _, _, opts) do
    continue = get_in(opts, [:params, :continue])

    case continue do
      "continue" -> {:error, %HTTPoison.Error{id: nil, reason: :checkout_timeout}}
      _ -> resp(%{"metadata" => %{"continue" => "continue"}, "items" => [%{"name" => "bar"}]})
    end
  end

  def request(:get, "apis/example.com/v1/watchers", _, _, opts) do
    stream_to = Keyword.get(opts, :stream_to)
    if stream_to != nil, do: send_chunk(stream_to, added_chunk())
    resp(%{})
  end

  def request(:get, "apis/example.com/v1/namespaces/default/widgets", _, _, _) do
    response = %{"metadata" => %{"resourceVersion" => "1337"}}
    resp(response)
  end

  def request(:get, "apis/example.com/v1/namespaces/default/cogs", _, _, _) do
    response = %{"metadata" => %{"resourceVersion" => "1"}}
    resp(response)
  end

  def request(method, url, body, headers, opts) do
    Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
  end

  @impl K8s.Client.Provider
  def headers(_, _), do: []

  @impl K8s.Client.Provider
  def handle_response({:error, %HTTPoison.Error{} = err}), do: {:error, err}

  def added_chunk() do
    "{\"type\":\"ADDED\",\"object\":{\"apiVersion\":\"example.com/v1\",\"kind\":\"Widget\",\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/last-applied-configuration\":\"{\\\"apiVersion\\\":\\\"example.com/v1\\\",\\\"kind\\\":\\\"Widget\\\",\\\"metadata\\\":{\\\"annotations\\\":{},\\\"name\\\":\\\"test-widget\\\",\\\"namespace\\\":\\\"default\\\"}}\\n\"},\"clusterName\":\"\",\"creationTimestamp\":\"2018-12-17T06:26:41Z\",\"generation\":1,\"name\":\"test-widget\",\"namespace\":\"default\",\"resourceVersion\":\"705460\",\"selfLink\":\"/apis/example.com/v1/namespaces/default/widgets/test-widget\",\"uid\":\"b7464e30-01c4-11e9-9066-025000000001\"}}}\n"
  end

  defp send_chunk(pid, chunk), do: send(pid, async_chunk(chunk))
  defp async_chunk(chunk), do: %HTTPoison.AsyncChunk{chunk: chunk}
end
