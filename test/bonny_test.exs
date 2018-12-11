defmodule Test.Bonny.WidgetList do
  defstruct [:api_version, :items, :kind, :metadata]
  @type t :: %Test.Bonny.WidgetList{
    api_version: String.t(),
    items: list(Test.Bonny.Widget.t()),
    kind: String.t(),
    metadata: Kazan.Models.Apimachinery.Meta.V1.ListMeta.t()
  }
end

defmodule Test.Bonny.Widget do
  defstruct [:api_version, :kind, :metadata, :spec, :status]
  @type t :: %Test.Bonny.Widget{
    api_version: String.t(),
    kind: String.t(),
    metadata: Kazan.Models.Apimachinery.Meta.V1.ObjectMeta.t(),
    spec: Test.Bonny.WidgetSpec.t(),
    status: Test.Bonny.WidgetStatus.t()
  }
end

defmodule Test.Bonny.WidgetSpec do
  defstruct [:finalizers]
  @type t :: %Test.Bonny.WidgetSpec{finalizers: String.t()}
end

defmodule Test.Bonny.WidgetStatus do
  defstruct [:phase]
  @type t :: %Test.Bonny.WidgetStatus{phase: String.t()}
end

defmodule BonnyTest do
  use ExUnit.Case
  doctest Bonny

  test "greets the world" do
    name = "something.test.widget"
    assert Kazan.Models.oai_name_to_module(name) == Test.Bonny.Widget
  end
end
