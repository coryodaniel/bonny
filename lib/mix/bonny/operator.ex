defmodule Mix.Bonny.Operator do
  def valid?(name) do
    name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end
end
