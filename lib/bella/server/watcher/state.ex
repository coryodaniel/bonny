defmodule Bella.Server.Watcher.State do
  @moduledoc "State of the Watcher"

  alias Bella.Server.Watcher.ResponseBuffer

  @type t :: %__MODULE__{
          resource_version: String.t() | nil,
          buffer: ResponseBuffer.t()
        }

  defstruct [:resource_version, :buffer]

  @spec new() :: t()
  def new() do
    %__MODULE__{
      resource_version: nil,
      buffer: ResponseBuffer.new()
    }
  end
end
