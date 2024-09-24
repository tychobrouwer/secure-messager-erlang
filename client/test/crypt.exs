defmodule CryptTest do
  use ExUnit.Case, async: true

  require Logger

  test "encrypt_message/4" do
    message = "Hello, world!"
    key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
    iv = Base.decode16!("48EA16CCF2829D493F9ADBADE344F061")

    encrypted_message_test = "0CA5C7CD7719C55D691D6806A1"

    signature_test =
      "32C1E443106D292E148E044E0207F58995158B787BEDB5F99693E850626B82D085D7D175B6E26D80C4E554FB43763333D3C6C1CFA61C54960EB1ED43DF2C910D"

    private_key =
      Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

    {encrypted_message, signature} = Crypt.encrypt_message(message, key, iv, private_key)

    assert Base.encode16(encrypted_message) == encrypted_message_test
    assert Base.encode16(signature) == signature_test
  end

  test "decrypt_message/5" do
    encrypted_message = Base.decode16!("0CA5C7CD7719C55D691D6806A1")
    key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
    iv = Base.decode16!("48EA16CCF2829D493F9ADBADE344F061")

    private_key =
      Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

    {public_key, _} = :crypto.generate_key(:eddh, :x25519, private_key)

    signature =
      Base.decode16!(
        "32C1E443106D292E148E044E0207F58995158B787BEDB5F99693E850626B82D085D7D175B6E26D80C4E554FB43763333D3C6C1CFA61C54960EB1ED43DF2C910D"
      )

    decrypted_message_test = "Hello, world!"

    {decrypted_message, valid} =
      Crypt.decrypt_message(encrypted_message, key, iv, public_key, signature)

    assert decrypted_message == decrypted_message_test
    # assert valid == true
  end
end
