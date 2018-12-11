defmodule Test.Bonny.WidgetList do
  defstruct [:api_version, :items, :kind, :metadata]
end

defmodule Test.Bonny.Widget do
  defstruct [:api_version, :kind, :metadata, :spec, :status]
end

defmodule Test.Bonny.WidgetSpec do
  defstruct [:name]
end

defmodule Test.Bonny.WidgetStatus do
  defstruct [:phase]
end

defmodule BonnyTest do
  use ExUnit.Case
  doctest Bonny

  test "greets the world" do
    name = "something.test.widget"
    assert Kazan.Models.oai_name_to_module(name) == Test.Bonny.Widget
  end
end
