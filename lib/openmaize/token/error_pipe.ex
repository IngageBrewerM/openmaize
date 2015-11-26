defmodule ErrorPipe do
  @moduledoc """
  Customized pipe.

  This pipe behaves like the regular Elixir pipe, but it exits if
  a tuple with {:error, message} is returned.
  """

  defmacro __using__(_) do
    quote do
      import ErrorPipe
    end
  end

  defmacro error_pipe(pipes) do
    [{h,_}|t] = Macro.unpipe(pipes)
    Enum.reduce t, h, &check_error/2
  end

  defp check_error({x, pos}, acc) do
    quote do
      case unquote(acc) do
        {:error, message} -> {:error, message}
        acc -> unquote(Macro.pipe(acc, x, pos))
      end
    end
  end

end
