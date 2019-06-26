defmodule Bonny.Sys.Event do
  @moduledoc false
  use Notion, name: :bonny, metadata: %{}

  defevent([:reconciler, :initialized])
  defevent([:reconciler, :run, :started])
  defevent([:reconciler, :run, :succeeded])
  defevent([:reconciler, :run, :failed])
  defevent([:reconciler, :fetch, :succeeded])
  defevent([:reconciler, :fetch, :failed])
end
