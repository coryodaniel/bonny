defmodule Bonny.Axn.Test do
  @moduledoc """
  Conveniences for testing Axn steps.

  This module can be used in your test cases, like this:

      use ExUnit.Case, async: true
      use Bonny.Axn.Test

  Using this module will:

    * import all the functions from this module
    * import all the functions from the `Bonny.Axn` module
    * import all the functions from the `Pluggable.Token` module
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Bonny.Axn.Test
      import Bonny.Axn
      import Pluggable.Token
    end
  end

  @default_resource %{
    "apiVersion" => "v1",
    "kind" => "ConfigMap",
    "metadata" => %{
      "name" => "foo",
      "namespace" => "default",
      "uid" => "foo-uid",
      "generation" => 1
    },
    "data" => %{
      "foo" => "lorem ipsum"
    }
  }

  @spec axn(atom(), Keyword.t()) :: Bonny.Axn.t()
  def axn(action, fields \\ []) do
    fields
    |> Keyword.put(:action, action)
    |> Keyword.put_new_lazy(:conn, fn -> Bonny.Config.conn() end)
    |> Keyword.put_new(:resource, @default_resource)
    |> Bonny.Axn.new!()
  end

  @spec descendants(Bonny.Axn.t()) :: list(Bonny.Resource.t())
  def descendants(%Bonny.Axn{descendants: descendants}), do: descendants

  @spec events(Bonny.Axn.t()) :: list(Bonny.Event.t())
  def events(%Bonny.Axn{events: events}), do: events

  @spec status(Bonny.Axn.t()) :: map()
  def status(%Bonny.Axn{status: status}), do: status

  @spec assigns(Bonny.Axn.t()) :: map()
  def assigns(%Bonny.Axn{assigns: assigns}), do: assigns
end
