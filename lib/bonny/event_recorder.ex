defmodule Bonny.EventRecorder do
  @moduledoc """
  Records kubernetes events regarding objects controlled by this operator.


  """

  use Agent

  alias Bonny.Resource

  @api_version "events.k8s.io/v1"
  @kind "Event"

  @type event_type :: :Normal | :Warning

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    conn = Keyword.fetch!(opts, :conn)
    Agent.start_link(fn -> %{conn: conn} end, name: name)
  end

  @doc """
  Create a kubernetes event in the cluster.
  Documentation: https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/
  """
  @spec event(
          atom(),
          Resource.t(),
          Resource.t() | nil,
          event_type(),
          binary(),
          binary(),
          binary()
        ) ::
          :ok
  def event(agent_name, regarding, related \\ nil, event_type, reason, action, message) do
    ref_regarding = Resource.resource_reference(regarding)
    ref_related = Resource.resource_reference(related)
    event_time = DateTime.utc_now()
    reporting_controller = Bonny.Config.name()
    reporting_instance = Bonny.Config.instance_name()
    conn = Agent.get(agent_name, &Map.fetch!(&1, :conn))
    unix_nano = DateTime.utc_now() |> DateTime.to_unix(:nanosecond)

    event = %{
      "apiVersion" => @api_version,
      "kind" => @kind,
      "metadata" => %{
        "namespace" => Map.get(ref_regarding, "namespace", "default"),
        "name" => "#{Map.fetch!(ref_regarding, "name")}.#{unix_nano}"
      },
      "eventTime" => event_time,
      "reportingController" => reporting_controller,
      "reportingInstance" => reporting_instance,
      "action" => action,
      "reason" => reason,
      "regarding" => ref_regarding,
      "related" => ref_related,
      "note" => message,
      "type" => event_type
    }

    key = key(event)

    event =
      get_cache(agent_name, key, event)
      |> increment_series_count()

    apply_op = K8s.Client.apply(event, field_manager: reporting_controller, force: true)
    {:ok, _} = K8s.Client.run(conn, apply_op)

    put_cache(agent_name, key, event)
    :ok
  end

  defp get_cache(agent_name, key, default) do
    Agent.get(agent_name, &Map.get(&1, key, default))
  end

  defp put_cache(agent_name, key, event) do
    event = Map.put_new(event, "series", %{"count" => 1})
    Agent.update(agent_name, &Map.put(&1, key, event))
  end

  defp increment_series_count(event) when is_map_key(event, "series") do
    Map.update!(
      event,
      "series",
      &%{"count" => &1["count"] + 1, "lastObservedTime" => DateTime.utc_now()}
    )
  end

  defp increment_series_count(event), do: event

  defp key(event) do
    %{
      action: event["action"],
      reason: event["reason"],
      reporting_controller: event["reportingController"],
      regarding: event["regarding"],
      related: event["related"]
    }
  end
end
