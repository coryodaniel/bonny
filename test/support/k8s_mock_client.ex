# credo:disable-for-this-file
defmodule Bella.K8sMockClient do
  @moduledoc """
  Mock `K8s.Client`
  """

  def stream(%K8s.Operation{api_version: "reconciler.test.foos/v1"} = _op, _cluster) do
    fake_stream = [
      %{"name" => "foo"},
      %{"name" => "bar"}
    ]

    {:ok, fake_stream}
  end

  def stream(%K8s.Operation{api_version: "reconciler.test.errors/v1"} = _op, _cluster) do
    fake_stream = [
      %{"name" => "bar"},
      {:error, :some_error}
    ]

    {:ok, fake_stream}
  end

  def list(api_version, name_or_kind), do: list(api_version, name_or_kind, [])

  def list(api_version, name_or_kind, path_params) do
    K8s.Operation.build(:list, api_version, name_or_kind, path_params)
  end

  def watch(_op, :test, opts) do
    watcher = opts[:stream_to]
    send_chunk(watcher, added_chunk())
    send_chunk(watcher, deleted_chunk())
  end

  # Mock for Reconciler.run/2
  def run(%K8s.Operation{name: "whizbangs", method: :get, verb: :list}, _,
        params: %{continue: nil, limit: 50}
      ) do
    response = %{
      "metadata" => %{"continue" => "foo"},
      "items" => [%{"page" => 1}]
    }

    {:ok, response}
  end

  def run(%K8s.Operation{name: "whizbangs", method: :get, verb: :list}, _,
        params: %{continue: "foo", limit: 50}
      ) do
    response = %{
      "metadata" => %{"continue" => ""},
      "items" => [%{"page" => 2}]
    }

    {:ok, response}
  end

  # TODO: remove; Pre 0.4: Mock response for Impl.get_resource_version/1
  def run(%K8s.Operation{name: "widgets", method: :get, verb: :list}, _, params: %{limit: 1}) do
    response = %{"metadata" => %{"resourceVersion" => "1337"}}
    {:ok, response}
  end

  def run(%K8s.Operation{api_version: "resourceVersion.test/v1"}, _, params: %{limit: 1}) do
    response = %{"metadata" => %{"resourceVersion" => "1337"}}
    {:ok, response}
  end

  # Mock response for Impl.watch_for_changes/2
  def run(%K8s.Operation{name: "cogs", method: :get, verb: :list}, _, _) do
    response = %{"metadata" => %{"resourceVersion" => "1"}}
    {:ok, response}
  end

  def run(_, _, _) do
    {:error, :mock_client}
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
