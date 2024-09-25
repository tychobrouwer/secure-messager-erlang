defmodule ClientTest do
  use ExUnit.Case, async: true

  require Logger

  test "start" do
    assert Client.start() == :ok
  end
end
