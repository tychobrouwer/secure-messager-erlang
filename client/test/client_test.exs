defmodule ClientTest do
  use ExUnit.Case, async: true

  doctest Client
  doctest Client.Message
  doctest Client.Utils
end
