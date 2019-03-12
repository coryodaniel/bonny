defmodule Bonny.K8sMockClient do
  def list(api_version, kind, path_params) do
    K8s.Operation.build(:list, api_version, kind, path_params)
  end

  def watch(_op, :test, opts) do
    # [params: %{resourceVersion: 1337}, stream_to: pid, recv_timeout: 300000]
    watcher = opts[:stream_to]
    send_chunk(watcher, added_chunk())
    send_chunk(watcher, deleted_chunk())
  end

  def run(_, _, _) do
    {:ok, %{"mock" => true}}
  end

  def added_chunk() do
    "{\"type\":\"ADDED\",\"object\":{\"apiVersion\":\"example.com/v1\",\"kind\":\"Widget\",\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/last-applied-configuration\":\"{\\\"apiVersion\\\":\\\"example.com/v1\\\",\\\"kind\\\":\\\"Widget\\\",\\\"metadata\\\":{\\\"annotations\\\":{},\\\"name\\\":\\\"test-widget\\\",\\\"namespace\\\":\\\"default\\\"}}\\n\"},\"clusterName\":\"\",\"creationTimestamp\":\"2018-12-17T06:26:41Z\",\"generation\":1,\"name\":\"test-widget\",\"namespace\":\"default\",\"resourceVersion\":\"705460\",\"selfLink\":\"/apis/example.com/v1/namespaces/default/widgets/test-widget\",\"uid\":\"b7464e30-01c4-11e9-9066-025000000001\"}}}\n"
  end

  def deleted_chunk() do
    "{\"type\":\"DELETED\",\"object\":{\"apiVersion\":\"example.com/v1\",\"kind\":\"Widget\",\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/last-applied-configuration\":\"{\\\"apiVersion\\\":\\\"example.com/v1\\\",\\\"kind\\\":\\\"Widget\\\",\\\"metadata\\\":{\\\"annotations\\\":{},\\\"name\\\":\\\"test-widget\\\",\\\"namespace\\\":\\\"default\\\"}}\\n\"},\"clusterName\":\"\",\"creationTimestamp\":\"2018-12-17T06:26:41Z\",\"generation\":1,\"name\":\"test-widget\",\"namespace\":\"default\",\"resourceVersion\":\"705464\",\"selfLink\":\"/apis/example.com/v1/namespaces/default/widgets/test-widget\",\"uid\":\"b7464e30-01c4-11e9-9066-025000000001\"}}}\n"
  end

  defp send_chunk(pid, chunk), do: send(pid, async_chunk(chunk))
  defp async_chunk(chunk), do: %HTTPoison.AsyncChunk{chunk: chunk}
end
