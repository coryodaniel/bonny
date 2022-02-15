defmodule TestScheduler do
  use Bonny.Server.Scheduler, name: "test-scheduler"

  def select_node_for_pod(_pod, nodes) do
    nodes
    |> Enum.take(1)
    |> List.first()
  end
end
