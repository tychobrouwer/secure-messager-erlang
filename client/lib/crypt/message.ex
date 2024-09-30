defmodule Crypt.Message do
  @moduledoc """
  Documentation for `Crypt`.
  """

  @doc """
  Encrypts a message with a key and an initialization vector.

  ## Examples

      iex> message = "Hello, world!"
      iex> key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> private_key = Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")
      iex> {encrypted_message, tag, signature} = Crypt.Message.encrypt(message, key, private_key)
      {encrypted_message, tag, signature}
  """

  @spec encrypt(binary, binary, binary) :: {binary, binary, binary}
  def encrypt(message, message_key, private_key) do
    message = pkcs7_pad(message, 16)

    salt_size = 80 * 8
    salt = <<0::size(salt_size)>>

    <<encryption_key::binary-size(32), authentication_key::binary-size(32), iv::binary-size(16)>> =
      Crypt.Hkdf.derive(message_key, 80, salt, "message_key")

    # encryption_key = :binary.part(hash, 0, 32)
    # authentication_key = :binary.part(hash, 32, 32)
    # iv = :binary.part(hash, 64, 16)

    associated_data = ""

    {encrypted_message, message_tag} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        encryption_key,
        iv,
        message,
        associated_data,
        true
      )

    mac_hash =
      :crypto.mac(:hmac, :sha256, authentication_key, associated_data <> encrypted_message)

    {encrypted_message, message_tag, mac_hash}
  end

  @doc """
  Decrypts a message with a key, an initialization vector, a public key, and a signature.

  ## Examples

        iex> encrypted_message = Base.decode16!("2D79EE847EA324214445EF171DCCDA40")
        iex> message_tag = Base.decode16!("F0E2112968C85A831CB84E2CC855A142")
        iex> key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
        iex> foreign_public_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
        iex> signature = Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")
        iex> {decrypted_message, valid} = Crypt.decrypt_message(encrypted_message, message_tag, key, foreign_public_key, signature)
        {decrypted_message, valid}
  """

  # message_data.message,
  # message_data.tag,
  # message_data.public_key,
  # message_data.hash

  @spec decrypt(binary, binary, binary, binary, binary, binary) :: {binary, boolean}
  def decrypt(encrypted_message, message_tag, foreign_public_key, hash, message_key, private_key) do
    salt_size = 80 * 8
    salt = <<0::size(salt_size)>>

    associated_data = ""

    <<encryption_key::binary-size(32), authentication_key::binary-size(32), iv::binary-size(16)>> =
      Crypt.Hkdf.derive(message_key, 80, salt, "message_key")

    {message, tag} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        encryption_key,
        iv,
        encrypted_message,
        associated_data,
        false
      )

    mac_hash =
      :crypto.mac(:hmac, :sha256, authentication_key, associated_data <> encrypted_message)

    valid = hash == mac_hash && tag == message_tag

    {message, valid}

    # zero_bytes = :binary.copy(<<0::size(8)>>, 80)
    # hash = Crypt.Hkdf.derive(message_key, 80, zero_bytes, "message_key")

    # encryption_key = :binary.part(hash, 0, 32)
    # authentication_key = :binary.part(hash, 32, 32)
    # iv = :binary.part(hash, 64, 16)

    # associated_data = ""

    # decrypted_message =
    #   :crypto.crypto_one_time_aead(
    #     :aes_256_gcm,
    #     encryption_key,
    #     iv,
    #     encrypted_message,
    #     associated_data,
    #     message_tag,
    #     false
    #   )

    # decrypted_message = pkcs7_unpad(decrypted_message)

    # mac_hash =
    #   :crypto.mac(:hmac, :sha256, authentication_key, associated_data <> encrypted_message)

    # valid =
    #   :crypto.verify(:eddsa, nil, encrypted_message, signature, [foreign_public_key, :ed25519])

    # {decrypted_message, valid}
  end

  defp pkcs7_pad(data, block_size) do
    padding = block_size - rem(byte_size(data), block_size)
    padding = if padding == 0, do: block_size, else: padding

    data <> :binary.copy(<<padding::size(8)>>, padding)
  end

  defp pkcs7_unpad(data) do
    length = :binary.last(data)
    length = if length > 0 and length <= 16, do: length, else: 0

    :binary.part(data, 0, byte_size(data) - length)
  end
end
