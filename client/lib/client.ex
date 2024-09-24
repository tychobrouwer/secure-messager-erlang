defmodule Client do
  @moduledoc """
  Documentation for `Client`.
  """

  require Logger

  @doc """
  Starts the client.

  ## Examples

      iex> Client.start()
      :ok
  """

  @spec start() :: :ok
  def start do
    Logger.info("Starting client")

    :ok
  end
end
