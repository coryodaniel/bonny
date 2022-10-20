defmodule Bonny.Axn.Test do
  @moduledoc """
  Conveniences for testing Axn steps.

  This module can be used in your test cases, like this:

      use ExUnit.Case, async: true
      use Plug.Test

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
    "apiVersion" => "example.com/v1",
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

  @spec axn(atom(), Bonny.Resource.t(), K8s.Conn.t(), atom()) :: Bonny.Axn.t()
  def axn(action, resource \\ @default_resource, conn \\ Bonny.Config.conn(), controller \\ nil) do
    Bonny.Axn.new!(conn: conn, action: action, resource: resource, controller: controller)
  end
end
