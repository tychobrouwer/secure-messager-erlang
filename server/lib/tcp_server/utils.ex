defmodule TCPServer.Utils do
  @spec uuid() :: binary
  def uuid() do
    perf_counter = :os.perf_counter()
    random = :rand.uniform(1_000_000)
    pid = :erlang.list_to_binary(:os.getpid())

    uuid_bytes = <<perf_counter::64, random::32>> <> pid

    Base.encode16(:crypto.hash(:sha, uuid_bytes), case: :lower)
  end
end