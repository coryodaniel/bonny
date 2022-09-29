defmodule Bonny.Test.API.V1.TestResourceV32 do
  @moduledoc false
  use Bonny.API.Version,
    hub: true

  @impl true
  def manifest() do
    defaults()
  end
end
