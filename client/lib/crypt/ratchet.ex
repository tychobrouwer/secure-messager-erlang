defmodule Crypt.Ratchet do
  @moduledoc """
  Documentation for `Ratchet`.

  This module provides functions for generating chain keys.
  """

  require Crypt.Keys
  require Crypt.Hkdf

  @type keypair :: Crypt.Keys.keypair()
  @type ratchet :: %{
          root_key: binary | nil,
          child_key: binary | nil
        }

  @doc """
  Initializes a ratchet with a root key.

  ## Examples

      iex> root_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> ratchet = %{root_key: root_key, child_key: nil}
      iex> keypair = Crypt.Keys.generate_keypair()
      iex> foreign_public_key = Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")
      iex> ratchet = Crypt.Ratchet.rk_cycle(ratchet, keypair, foreign_public_key)
      ratchet
  """

  @spec rk_cycle(ratchet, keypair, binary) :: ratchet
  def rk_cycle(ratchet, keypair, foreign_public_key) do
    root_key = ratchet.root_key

    # Generate new shared secret using DH key exchange
    dh_key = Crypt.Keys.generate_eddh_secret(keypair, foreign_public_key)

    # Generate new root and chain key
    {new_root_key, chain_key} = kdf_rk(root_key, dh_key)

    %{root_key: new_root_key, child_key: chain_key}
  end

  @doc """
  Generates the next ratchet key from a ratchet key.

  ## Examples

      iex> ratchet_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> ratchet = Crypt.Ratchet.ck_cycle(ratchet_key)
      ratchet
  """

  @spec ck_cycle(binary) :: {binary, binary, binary}
  def ck_cycle(chain_key) do
    # Generate new message key and chain key
    {chain_key, message_key} = kdf_ck(chain_key)

    %{root_key: chain_key, child_key: message_key}
  end

  @spec kdf_rk(binary, binary) :: {binary, binary}
  defp kdf_rk(root_key, dh_key) do
    key = Crypt.Hkdf.derive(dh_key, 64, root_key, "r")

    root_key = :binary.part(key, 0, 32)
    chain_key = :binary.part(key, 32, 32)

    {root_key, chain_key}
  end

  @spec kdf_ck(binary) :: {binary, binary}
  defp kdf_ck(chain_key) do
    chain_key = Crypt.Hkdf.derive(chain_key, 32, "m")
    message_key = Crypt.Hkdf.derive(chain_key, 32, "c")

    {chain_key, message_key}
  end
end
