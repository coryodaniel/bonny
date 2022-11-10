defmodule Bonny.OperatorTest do
  use ExUnit.Case, async: true
  use Bonny.Axn.Test

  test "does not compile if :default_watch_namespace option is missing" do
    assert_raise CompileError, ~r/operator expects :default_watch_namespace to be given/, fn ->
      defmodule SomeOperator1 do
        use Bonny.Operator
      end
    end
  end

  test "does not compile if step :delegate_to_controller is missing" do
    assert_raise CompileError, ~r/Operators must define a step :delegate_to_controller/, fn ->
      defmodule SomeOperator2 do
        use Bonny.Operator, default_watch_namespace: "default"
      end
    end
  end

  test "compiles" do
    defmodule SomeOperator3 do
      use Bonny.Operator, default_watch_namespace: "default"

      step :delegate_to_controller

      def controllers(_, _), do: []
      def crds(), do: []
    end
  end

  defmodule TestOperator do
    use Bonny.Operator, default_watch_namespace: "default"

    step :delegate_to_controller

    def controllers(_, _), do: []
    def crds(), do: []
  end

  test "delegates to controller with init opts" do
    defmodule TestController do
      @behaviour Pluggable

      @impl Pluggable
      def init(opts), do: Keyword.get(opts, :foo)
      @impl Pluggable
      def call(axn, foo) do
        Pluggable.Token.assign(axn, :foo, foo)
      end
    end

    assert nil ==
             axn(:add, controller: {TestController, []})
             |> TestOperator.delegate_to_controller(nil)
             |> assigns()
             |> Map.get(:foo)

    assert :bar ==
             axn(:add, controller: {TestController, [foo: :bar]})
             |> TestOperator.delegate_to_controller(nil)
             |> assigns()
             |> Map.get(:foo)
  end
end
