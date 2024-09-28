defmodule CryptTester do
  use ExUnit.Case, async: true
  doctest Crypt

  require Logger

  test "encrypt_message/3" do
    message = "Hello, world!"
    key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")

    encrypted_message_test = "2D79EE847EA324214445EF171DCCDA40"
    message_tag_test = "F0E2112968C85A831CB84E2CC855A142"

    signature_test =
      "747E3F4FBBEFB6B69BF16150A519890DD3BD54D7A88902101900ABC4E170C8D91EE0E460273C9413ED255EDC1F87F512F6A9E4F506F7A2BA4A1E85A6009A500F"

    private_key =
      Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

    {encrypted_message, message_tag, signature} = Crypt.encrypt_message(message, key, private_key)

    assert Base.encode16(encrypted_message) == encrypted_message_test
    assert Base.encode16(signature) == signature_test
    assert Base.encode16(message_tag) == message_tag_test
  end

  test "decrypt_message/4" do
    encrypted_message = Base.decode16!("2D79EE847EA324214445EF171DCCDA40")
    message_tag = Base.decode16!("F0E2112968C85A831CB84E2CC855A142")
    key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")

    private_key =
      Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

    {foreign_public_key, _} = :crypto.generate_key(:eddh, :x25519, private_key)

    signature =
      Base.decode16!(
        "747E3F4FBBEFB6B69BF16150A519890DD3BD54D7A88902101900ABC4E170C8D91EE0E460273C9413ED255EDC1F87F512F6A9E4F506F7A2BA4A1E85A6009A500F"
      )

    decrypted_message_test = "Hello, world!"

    {decrypted_message, _} =
      Crypt.decrypt_message(encrypted_message, message_tag, key, foreign_public_key, signature)

    assert decrypted_message == decrypted_message_test
    # assert valid == true
  end
end
