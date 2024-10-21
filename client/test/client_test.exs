defmodule ClientTest do
  use ExUnit.Case, async: true

  doctest Client
  doctest Client.Account
  doctest Client.Contact
  doctest Client.Message
  doctest Client.Utils
end
