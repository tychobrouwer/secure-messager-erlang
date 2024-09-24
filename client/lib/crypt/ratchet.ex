defmodule Crypt.Ratchet do
  @moduledoc """
  Documentation for `Ratchet`.

  This module provides functions for generating chain keys.
  """

  require Crypt.Keys

  @doc """
  Generates the next chain key from a chain key.

  ## Examples

      iex> chain_key = Base.decode("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> {:ok, key, outkey, iv} = Crypt.Ratchet.next_chain_key(chain_key)
      {:ok, key, outkey, iv}
  """

  @spec next_chain_key(binary) :: {:ok, binary, binary, binary} | {:error, term}
  def next_chain_key(chain_key) do
    {status, output} = Crypt.Keys.generate_kdf_secret(chain_key, 80)

    <<key::binary-size(32), output::binary>> = output
    <<outkey::binary-size(32), iv::binary>> = output

    {status, key, outkey, iv}
  end
end
