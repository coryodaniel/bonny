defmodule Bonny.Sys.Event do
  @moduledoc false
  use Notion, name: :bonny, metadata: %{}

  defevent([:reconciler, :run, :succeeded])
  defevent([:reconciler, :run, :failed])
  defevent([:reconciler, :resources, :succeeded])
  defevent([:reconciler, :resources, :failed])
end
