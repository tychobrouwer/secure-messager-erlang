defmodule ClientTest do
  use ExUnit.Case

  doctest Client
  doctest Client.Account
  doctest Client.Contact
  doctest Client.Message
  doctest Client.Utils

  test "signup" do
    random = get_random_utf8_string()

    nil_token = <<0::size(29 * 8)>>
    token = Client.Account.signup(random, random)

    assert token != nil
    assert byte_size(token) == 29
    assert token != nil_token
  end

  test "signup_failed" do
    random = get_random_utf8_string()

    nil_token = <<0::size(29 * 8)>>
    token = Client.Account.signup(random, random)

    assert token != nil
    assert byte_size(token) == 29
    assert token != nil_token

    token = Client.Account.signup(random, random)

    assert token == nil_token
  end

  test "login" do
    random = get_random_utf8_string()

    nil_token = <<0::size(29 * 8)>>
    token = Client.Account.signup(random, random)

    assert token != nil
    assert byte_size(token) == 29
    assert token != nil_token

    token = Client.Account.login(random, random)

    assert token != nil
    assert byte_size(token) == 29
    assert token != nil_token
  end

  test "login_failed" do
    random = get_random_utf8_string()
    random1 = get_random_utf8_string()

    nil_token = <<0::size(29 * 8)>>
    token = Client.Account.signup(random, random)

    assert token != nil
    assert byte_size(token) == 29
    assert token != nil_token

    token = Client.Account.login(random, random1)

    assert token == nil_token
  end

  def get_random_utf8_string() do
    :crypto.strong_rand_bytes(10)
    |> Base.url_encode64(padding: false)
  end
end
