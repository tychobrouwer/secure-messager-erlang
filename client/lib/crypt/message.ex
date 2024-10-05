defmodule Crypt.Message do
  @moduledoc """
  Documentation for `Crypt`.
  """
require Logger

  @doc """
  Encrypts a message with a key and an initialization vector.

  ## Examples

      iex> message = "Hello, world!"
      iex> key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> {encrypted_message, tag, signature} = Crypt.Message.encrypt(message, key)
      {encrypted_message, tag, signature}
  """

  @spec encrypt(binary, binary) :: {binary, binary, binary}
  def encrypt(message, message_key) do
    message = pkcs7_pad(message, 16)

    salt_size = 80 * 8
    salt = <<0::size(salt_size)>>

    <<encryption_key::binary-size(32), authentication_key::binary-size(32), iv::binary-size(16)>> =
      Crypt.Hkdf.derive(message_key, 80, salt, "message_key")

    Logger.info(
      "message key: \"#{Base.encode64(message_key)}\""
    )

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

    Logger.info(
      "encrypted message: \"#{Base.encode64(encrypted_message)}\", key: \"#{Base.encode64(encryption_key)}\", iv: \"#{Base.encode64(iv)}\", associated data: \"#{Base.encode64(associated_data)}\", message tag \"#{Base.encode64(message_tag)}\""
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

  @spec decrypt(binary, binary, binary, binary) :: {binary, boolean}
  def decrypt(encrypted_message, message_tag, hash, message_key) do
    salt_size = 80 * 8
    salt = <<0::size(salt_size)>>

    associated_data = ""

    <<encryption_key::binary-size(32), authentication_key::binary-size(32), iv::binary-size(16)>> =
      Crypt.Hkdf.derive(message_key, 80, salt, "message_key")


    Logger.info(
      "message key: \"#{Base.encode64(message_key)}\""
    )

    decrypt_result = :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        encryption_key,
        iv,
        encrypted_message,
        associated_data,
        message_tag,
        false
      )

    Logger.info(
      "encrypted message: \"#{Base.encode64(encrypted_message)}\", key: \"#{Base.encode64(encryption_key)}\", iv: \"#{Base.encode64(iv)}\", associated data: \"#{Base.encode64(associated_data)}\", message tag \"#{Base.encode64(message_tag)}\""
    )

    {message, tag} = case decrypt_result do
      {padded_message, tag} ->
        message = pkcs7_unpad(padded_message)

        {message, tag}
      decrypt_error ->
        Logger.warning(inspect(decrypt_error))
        {~c"", ~c""}
    end

    mac_hash =
      :crypto.mac(:hmac, :sha256, authentication_key, associated_data <> encrypted_message)

    valid = hash == mac_hash && tag == message_tag

    {message, valid}
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
