defmodule Bella.PeriodicTaskTest do
  use ExUnit.Case, async: false
  alias Bella.PeriodicTask

  defmodule Dummy do
    def handler(state) do
      {:ok, Bella.PeriodicTaskTest.increment_state(state)}
    end
  end

  describe "new/1" do
    test "creates and registers a task" do
      task_id = :register_mf
      agent_pid = make_agent(task_id)
      PeriodicTask.start_link(nil)

      task = %PeriodicTask{
        id: task_id,
        handler: {Bella.PeriodicTaskTest.Dummy, :handler},
        interval: 5,
        state: agent_pid
      }

      {:ok, _child_pid} = PeriodicTask.register(task)

      :timer.sleep(10)

      assert Agent.get(agent_pid, & &1) in 1..2
      DynamicSupervisor.stop(PeriodicTask)
    end
  end

  describe "register/1" do
    test "runs an mf" do
      task_id = :register_mf
      agent_pid = make_agent(task_id)
      PeriodicTask.start_link(nil)

      task = %PeriodicTask{
        id: task_id,
        handler: {Bella.PeriodicTaskTest.Dummy, :handler},
        interval: 5,
        state: agent_pid
      }

      {:ok, _child_pid} = PeriodicTask.register(task)

      :timer.sleep(10)

      assert Agent.get(agent_pid, & &1) in 1..2
      DynamicSupervisor.stop(PeriodicTask)
    end

    test "runs an mfa" do
      task_id = :register_mfa
      agent_pid = make_agent(task_id)
      PeriodicTask.start_link(nil)

      task = %PeriodicTask{
        id: task_id,
        handler: {Bella.PeriodicTaskTest.Dummy, :handler, [agent_pid]},
        interval: 5
      }

      {:ok, _child_pid} = PeriodicTask.register(task)

      :timer.sleep(10)

      assert Agent.get(agent_pid, & &1) in 1..2
      DynamicSupervisor.stop(PeriodicTask)
    end

    test "runs an anonymous function" do
      task_id = :register_func
      agent_pid = make_agent(task_id)
      PeriodicTask.start_link(nil)

      handler = fn agent_pid ->
        increment_state(agent_pid)
        {:ok, agent_pid}
      end

      task = %PeriodicTask{
        id: task_id,
        handler: handler,
        interval: 5,
        state: agent_pid
      }

      {:ok, _child_pid} = PeriodicTask.register(task)

      :timer.sleep(10)

      assert Agent.get(agent_pid, & &1) in 1..2
      DynamicSupervisor.stop(PeriodicTask)
    end

    test "runs multiple tasks" do
      PeriodicTask.start_link(nil)

      {_task_pid, agent_name1} = make_increment_task(:task1, 5)
      {_task_pid, agent_name2} = make_increment_task(:task2, 25)

      :timer.sleep(50)
      assert Agent.get(agent_name1, & &1) in 8..10
      assert Agent.get(agent_name2, & &1) in 1..2
      DynamicSupervisor.stop(PeriodicTask)
    end
  end

  describe "unregister/1" do
    test "unregisters and stops a task" do
      PeriodicTask.start_link(nil)

      {_task_pid, agent_name} = make_increment_task(:unregister, 25)

      :timer.sleep(50)
      assert Agent.get(agent_name, & &1) in 1..3
      PeriodicTask.unregister(:unregister)
      previous_value = Agent.get(agent_name, & &1)

      :timer.sleep(50)
      current_value = Agent.get(agent_name, & &1)
      assert previous_value == current_value

      DynamicSupervisor.stop(PeriodicTask)
    end
  end

  def increment_state(pid) do
    Agent.update(pid, fn n -> n + 1 end)
  end

  def make_agent(name) do
    agent_name = :"#{name}_agent"
    {:ok, _pid} = Agent.start_link(fn -> 0 end, name: agent_name)
    agent_name
  end

  def make_increment_task(task_id, interval) do
    agent_name = make_agent(task_id)

    handler = fn agent_pid ->
      increment_state(agent_pid)
      {:ok, agent_pid}
    end

    task = %PeriodicTask{
      id: task_id,
      handler: handler,
      interval: interval,
      state: agent_name
    }

    {:ok, task_pid} = PeriodicTask.register(task)
    {task_pid, agent_name}
  end
end
