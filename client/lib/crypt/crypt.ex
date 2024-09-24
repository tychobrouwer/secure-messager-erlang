defmodule Crypt do
  @moduledoc """
  Documentation for `Crypt`.
  """

  require Logger

  @doc """
  Encrypts a message with a key and an initialization vector.

  ## Examples

      iex> message = "Hello, world!"
      iex> key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> iv = Base.decode16!("48EA16CCF2829D493F9ADBADE344F061")
      iex> private_key = Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

      iex> {encrypted_message, signature} = Crypt.encrypt_message(message, key, iv, private_key)
      {encrypted_message, signature}
  """

  @spec encrypt_message(binary, binary, binary, binary) :: {binary, binary}
  def encrypt_message(message, key, iv, private_key) do
    encrypted_message = :crypto.crypto_one_time(:aes_ctr, key, iv, message, true)

    signature = :crypto.sign(:eddsa, nil, encrypted_message, [private_key, :ed25519])

    {encrypted_message, signature}
  end

  @doc """
  Decrypts a message with a key, an initialization vector, a public key, and a signature.

  ## Examples

        iex> encrypted_message = Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")
        iex> key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
        iex> iv = Base.decode16!("48EA16CCF2829D493F9ADBADE344F061")
        iex> public_key = Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")
        iex> signature = Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

        iex> {decrypted_message, valid} = Crypt.decrypt_message(encrypted_message, key, iv, public_key, signature)
        {decrypted_message, valid}
  """

  @spec decrypt_message(binary, binary, binary, binary, binary) :: {binary, boolean}
  def decrypt_message(encrypted_message, key, iv, public_key, signature) do
    decrypted_message = :crypto.crypto_one_time(:aes_ctr, key, iv, encrypted_message, false)

    valid = :crypto.verify(:eddsa, nil, encrypted_message, signature, [public_key, :ed25519])

    {decrypted_message, valid}
  end
end
