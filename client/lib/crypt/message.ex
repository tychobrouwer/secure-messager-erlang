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
      iex> {encrypted_message, tag, hash} = Crypt.Message.encrypt(message, key)
      {encrypted_message, tag, hash}
  """

  @spec encrypt(binary, binary) :: {binary, binary, binary}
  def encrypt(message, message_key) do
    message = pkcs7_pad(message, 16)

    salt_size = 80 * 8
    salt = <<0::size(salt_size)>>

    <<encryption_key::binary-size(32), authentication_key::binary-size(32), iv::binary-size(16)>> =
      Crypt.Hkdf.derive(message_key, 80, salt, "message_key")

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

        iex> encrypted_message = Base.decode64!("LXnuhH6jJCFERe8XHczaQA==")
        iex> message_tag = Base.decode64!("8OIRKWjIWoMcuE4syFWhQg==")
        iex> hash = Base.decode64!("hrkbwQdWgkqUYzZ0+kouJ+RbMJf5V6xYIRLnMwJOrGQ=")
        iex> key = Base.decode64!("eEWHtxMJ0cR3T2/fn+UWB1PEDvZ/FFymIXfGyjbCFR0=")
        iex> {decrypted_message, valid} = Crypt.Message.decrypt(encrypted_message, message_tag, hash, key)
        {decrypted_message, valid}
  """

  @spec decrypt(binary, binary, binary, binary) :: {binary, boolean}
  def decrypt(encrypted_message, message_tag, hash, message_key) do
    salt_size = 80 * 8
    salt = <<0::size(salt_size)>>

    associated_data = ""

    <<encryption_key::binary-size(32), authentication_key::binary-size(32), iv::binary-size(16)>> =
      Crypt.Hkdf.derive(message_key, 80, salt, "message_key")

    decrypt_result =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        encryption_key,
        iv,
        encrypted_message,
        associated_data,
        message_tag,
        false
      )

    message =
      case decrypt_result do
        :error ->
          Logger.error("Failed to decrypt message")

          ~c""

        padded_message ->
          pkcs7_unpad(padded_message)
      end

    mac_hash =
      :crypto.mac(:hmac, :sha256, authentication_key, associated_data <> encrypted_message)

    valid = hash == mac_hash

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
