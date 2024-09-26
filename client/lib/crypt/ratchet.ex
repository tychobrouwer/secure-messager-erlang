defmodule Crypt.Ratchet do
  @moduledoc """
  Documentation for `Ratchet`.

  This module provides functions for generating chain keys.
  """

  require Crypt.Keys

  @type keypair :: Crypt.Keys.keypair()
  @type ratchet :: %{
          root_key: binary | nil,
          child_key: binary | nil,
          iv_key: binary | nil
        }

  @doc """
  Initializes a ratchet with a root key.

  ## Examples

      iex> root_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> ratchet = %{root_key: root_key, child_key: nil, iv_key: nil}
      iex> keypair = Crypt.Keys.generate_keypair()
      iex> foreign_public_key = Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")
      iex> ratchet = Crypt.Ratchet.ratchet_init(ratchet, keypair, foreign_public_key)
      ratchet
  """

  @spec ratchet_init(ratchet, keypair, binary) :: ratchet
  def ratchet_init(ratchet, keypair, foreign_public_key) do
    root_key = ratchet.root_key

    # Generate new shared secret using DH key exchange
    shared_secret = Crypt.Keys.generate_eddh_secret(keypair, foreign_public_key)

    # Generate new root and ratchet key
    {new_root_key, ratchet_key, _} = next_chain_key(root_key, shared_secret)

    %{root_key: new_root_key, child_key: ratchet_key, iv_key: nil}
  end

  @doc """
  Generates the next ratchet key from a ratchet key.

  ## Examples

      iex> ratchet_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> ratchet = Crypt.Ratchet.ratchet_cycle(ratchet_key)
      ratchet
  """

  @spec ratchet_cycle(binary) :: {binary, binary, binary}
  def ratchet_cycle(ratchet_key) do
    # Generate new message key and IV and cycle ratchet key
    {new_ratchet_key, message_key, message_iv} = next_chain_key(ratchet_key)

    %{root_key: new_ratchet_key, child_key: message_key, iv_key: message_iv}
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
