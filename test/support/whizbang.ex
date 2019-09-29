# credo:disable-for-this-file
defmodule Whizbang do
  @moduledoc false
  use Bonny.Controller
  use Agent

  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get() do
    Agent.get(__MODULE__, fn events -> events end)
  end

  def get(type) do
    Agent.get(__MODULE__, fn events ->
      Keyword.get_values(events, type)
    end)
  end

  def put(event) do
    Agent.update(__MODULE__, fn events -> [event | events] end)
  end

  @impl true
  def add(evt), do: put({:added, evt})
  @impl true
  def modify(evt), do: put({:modified, evt})
  @impl true
  def delete(evt), do: put({:deleted, evt})
  @impl true
  def reconcile(evt), do: put({:reconciled, evt})
end

defmodule V1.Whizbang do
  @moduledoc false
  use Bonny.Controller
  @kind "Whizzo"
  @names %{kind: "Whizzo"}

  @impl true
  def add(_), do: :ok
  @impl true
  def modify(_), do: :ok
  @impl true
  def delete(_), do: :ok
  @impl true
  def reconcile(_), do: :ok
end

defmodule V2.Whizbang do
  @moduledoc false
  use Bonny.Controller

  @rule {"apiextensions.k8s.io", ["bar"], ["*"]}
  @rule {"apiextensions.k8s.io", ["foo"], ["*"]}

  @group "kewl.example.io"
  @scope :cluster
  @names %{
    plural: "bars",
    singular: "qux",
    kind: "Foo",
    shortNames: ["f", "b", "q"]
  }

  @impl true
  def add(_), do: :ok
  @impl true
  def modify(_), do: :ok
  @impl true
  def delete(_), do: :ok
  @impl true
  def reconcile(_), do: :ok
end

defmodule V3.Whizbang do
  @moduledoc false
  use Bonny.Controller

  @version "v3alpha1"
  @group "kewl.example.io"
  @scope :cluster
  @names %{
    plural: "foos",
    singular: "foo",
    kind: "Foo"
  }
  @additional_printer_columns [
    %{
      name: "test",
      type: "string",
      description: "test",
      JSONPath: ".spec.test"
    }
  ]

  @impl true
  def add(_), do: :ok
  @impl true
  def modify(_), do: :ok
  @impl true
  def delete(_), do: :ok
  @impl true
  def reconcile(_), do: :ok
end
