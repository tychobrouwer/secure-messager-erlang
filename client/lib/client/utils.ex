defmodule Client.Utils do
  @moduledoc """
  Utility functions for the client
  """

  @spec uuid() :: binary
  def uuid() do
    perf_counter = :os.perf_counter()
    random = :rand.uniform(1_000_000)
    pid = :erlang.list_to_binary(:os.getpid())

    uuid_bytes = <<perf_counter::64, random::32>> <> pid

    :crypto.hash(:sha, uuid_bytes)
  end
end
