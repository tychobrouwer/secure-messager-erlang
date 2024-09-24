defmodule KeysTest do
  use ExUnit.Case
  doctest Crypt.Keys

  require Logger

  test "generate_keypair/0" do
    {status, public_key, private_key} = Crypt.Keys.generate_keypair()

    assert status == :ok
    assert byte_size(public_key) == 65
    assert byte_size(private_key) == 32
  end

  test "generate_ecdh_secret/2" do
    public_key =
      Base.decode16!(
        "0443216ACE41DA2BCCABB04481CFF57B4B1944DF6C8BB4870A33AA6E2B74FD7073F7A1153970982C4E937A69B54DDB2DA180C584BD1F8B25938C154E27B3DFD663"
      )

    private_key =
      Base.decode16!("227A1C52D8706836090CB42C4659C9B13CEA0DB40D278D9FF37E4F3531C99440")

    shared_secret_test = "784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D"

    {status, shared_secret} = Crypt.Keys.generate_ecdh_secret(private_key, public_key)

    assert status == :ok
    assert Base.encode16(shared_secret) == shared_secret_test
  end

  test "generate_kdf_secret/2" do
    key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
    length = 80

    new_key_test =
      "B88B85AFF9E6039891E35C82F426915E6E1D90088481BE6238B47AFED1131DCC3BD7F5B1EC8BA060909FE0C2000BE2C929BAF8D373F0595090E56D3727789879F20D166279BEA4E5EE36D96630D72253"

    {status, new_key} = Crypt.Keys.generate_kdf_secret(key, length)

    assert status == :ok
    assert Base.encode16(new_key) == new_key_test
  end
end
