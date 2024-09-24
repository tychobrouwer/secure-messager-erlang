defmodule KeysTest do
  use ExUnit.Case, async: true
  doctest Crypt.Keys

  require Logger

  test "generate_keypair/0" do
    {public_key, private_key} = Crypt.Keys.generate_keypair()

    assert byte_size(public_key) == 32
    assert byte_size(private_key) == 32
  end

  test "generate_eddh_secret/2" do
    public_key =
      Base.decode16!("A1EAF8F96EC553733FC0636C162822AB35F1279F56A1FBB6476FD9838386931F")

    private_key =
      Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

    shared_secret_test = "C7DEB05D6332D62EAFF7C61A8E211EFC28FDAB6871D1226C1178AE80E3C9266B"

    shared_secret = Crypt.Keys.generate_eddh_secret(public_key, private_key)

    assert byte_size(shared_secret) == 32
    assert Base.encode16(shared_secret) == shared_secret_test
  end

  test "generate_kdf_secret/2" do
    key = Base.decode16!("C7DEB05D6332D62EAFF7C61A8E211EFC28FDAB6871D1226C1178AE80E3C9266B")
    length = 80

    new_key_test =
      "558B4404C868C0CCF9A88EC5C2DA010EFA011AEE6ACD56AD32E47C8F9E79467B1A7160680B0A4B36604730F4AC38FCE60E2CB5C0C0FBF3F00885A87215E1D3E9F2AA0BF8EA1C13328E1920EDD4DDF82A"

    new_key = Crypt.Keys.generate_kdf_secret(key, length)

    assert byte_size(new_key) == length
    assert Base.encode16(new_key) == new_key_test
  end
end
