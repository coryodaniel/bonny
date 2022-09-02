# credo:disable-for-this-file

defmodule V1.Whizbang do
  @moduledoc false
  use Bonny.Controller

  def conn(), do: Bonny.Test.IntegrationHelper.conn()

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
