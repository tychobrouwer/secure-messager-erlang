defmodule Crypt.Ratchet do
  @moduledoc """
  Documentation for `Ratchet`.

  This module provides functions for generating chain keys.
  """

  require Crypt.Keys

  @doc """
  Initializes a ratchet with a root key.

  ## Examples

      iex> root_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> {private_key, _} = Crypt.Keys.generate_keypair()
      iex> {_, foreign_public_key} = Crypt.Keys.generate_keypair()
      iex> {new_root_key, new_ratchet_key, message_key, message_iv} = Crypt.Ratchet.ratchet_init(root_key, private_key, foreign_public_key)
      {new_root_key, new_ratchet_key, message_key, message_iv}
  """

  @spec ratchet_init(binary, binary, binary) :: {binary, binary, binary, binary}
  def ratchet_init(root_key, private_key, foreign_public_key) do
    # Generate new shared secret using DH key exchange
    shared_secret = Crypt.Keys.generate_eddh_secret(private_key, foreign_public_key)

    # Generate new root and ratchet key
    {new_root_key, ratchet_key, _} = next_chain_key(root_key, shared_secret)

    # Generate new message key and IV and cycle ratchet key
    {new_ratchet_key, message_key, message_iv} = next_chain_key(ratchet_key)

    {new_root_key, new_ratchet_key, message_key, message_iv}
  end

  @doc """
  Generates the next ratchet key from a ratchet key.

  ## Examples

      iex> ratchet_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> {new_ratchet_key, message_key, message_iv} = Crypt.Ratchet.ratchet_cycle(ratchet_key)
      {new_ratchet_key, message_key, message_iv}
  """

  @spec ratchet_cycle(binary) :: {binary, binary, binary}
  def ratchet_cycle(ratchet_key) do
    # Generate new message key and IV and cycle ratchet key
    {new_ratchet_key, message_key, message_iv} = next_chain_key(ratchet_key)

    {new_ratchet_key, message_key, message_iv}
  end

  @doc """
  Generates the next chain key from a chain key.

  ## Examples

      iex> key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> {key, outkey, iv} = Crypt.Ratchet.next_chain_key(key)
      {key, outkey, iv}

      iex> key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> inp_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> {key, outkey, iv} = Crypt.Ratchet.next_chain_key(key, inp_key)
      {key, outkey, iv}
  """

  @spec next_chain_key(binary, binary) :: {binary, binary, binary}
  def next_chain_key(key, inp_key \\ "") do
    output = Crypt.Keys.generate_kdf_secret(key <> inp_key, 80)

    <<key_1::binary-size(32), output::binary>> = output
    <<out_key::binary-size(32), iv::binary>> = output

    {key_1, out_key, iv}
  end
end
