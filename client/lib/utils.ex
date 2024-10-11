defmodule Utils do
  require Logger

  @spec exit_on_nil(any, String.t()) :: :ok
  def exit_on_nil(value, location) do
    if value == nil do
      name = Macro.to_string(quote do: value)

      Logger.error("Nil value for #{name} at #{location}")
      exit(String.to_atom("nil_#{name}_#{location}"))
    end

    :ok
  end
end
