defmodule V1.Whizbang do
  @moduledoc false
  use Bonny.Operator
  def add(_), do: nil
  def modify(_), do: nil
  def delete(_), do: nil
end

defmodule V2.Whizbang do
  @moduledoc false
  use Bonny.Operator

  @rule {"apiextensions.k8s.io", ["bar"], ["*"]}
  @rule {"apiextensions.k8s.io", ["foo"], ["*"]}

  @version "v2alpha1"
  @group "kewl.example.io"
  @scope :cluster
  @names %{
    plural: "foos",
    singular: "foo",
    kind: "Foo"
  }

  def add(_), do: nil
  def modify(_), do: nil
  def delete(_), do: nil
end
