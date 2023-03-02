defmodule Bonny.Test.CompileTimeAssertions do
  defmodule DidNotRaise, do: defstruct(message: nil)

  defmacro assert_compile_time_raise(expected_exception, expected_message, fun) do
    actual_exception =
      try do
        Code.eval_quoted(fun)
        %DidNotRaise{}
      rescue
        e -> e
      end
      |> Macro.escape()

    quote do
      assert is_struct(unquote(actual_exception), unquote(expected_exception))
      assert Exception.message(unquote(actual_exception)) =~ unquote(expected_message)
    end
  end
end
