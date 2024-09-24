defmodule Crypt.Keys do
  @moduledoc """
  Documentation for `Keys`.

  This module provides functions for generating keys and secrets.
  """

  @doc """
  Generates a keypair for ECDH.

  ## Examples

      iex> {:ok, public_key, private_key} = Crypt.Keys.generate_keypair()
      {:ok, public_key, private_key}
  """

  @spec generate_keypair() :: {:ok, binary, binary}
  def generate_keypair do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256r1)

    {:ok, public_key, private_key}
  end

  @doc """
  Generates a shared secret from a private key and a public key.

  ## Examples

      iex> public_key = Base.decode16!("0443216ACE41DA2BCCABB04481CFF57B4B1944DF6C8BB4870A33AA6E2B74FD7073F7A1153970982C4E937A69B54DDB2DA180C584BD1F8B25938C154E27B3DFD663")
      iex> private_key = Base.decode16!("227A1C52D8706836090CB42C4659C9B13CEA0DB40D278D9FF37E4F3531C99440")
      iex> {:ok, shared_key} = Crypt.Keys.generate_ecdh_secret(private_key, public_key)
      {:ok, shared_key}
  """

  @spec generate_ecdh_secret(binary, binary) :: {:ok, binary}
  def generate_ecdh_secret(private_key, public_key) do
    shared_key = :crypto.compute_key(:ecdh, public_key, private_key, :secp256r1)

    {:ok, shared_key}
  end

  @doc """
  Generates a key from a key derivation function.

  ## Examples

      iex> key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> length = 80
      iex> {:ok, new_key} = Crypt.Keys.generate_kdf_secret(key, length)
      {:ok, new_key}
  """

  @spec generate_kdf_secret(binary, integer) :: {:ok, binary}
  def generate_kdf_secret(key, length) do
    new_key = :crypto.pbkdf2_hmac(:sha256, key, "", 1, length)

    {:ok, new_key}
  end
end
