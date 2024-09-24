defmodule Keys do
  @moduledoc """
  Documentation for `Keys`.
  """

  require Logger

  def generate_keypair do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256r1)

    {:ok, public_key, private_key}
  end

  def generate_shared_secret(private_key, public_key) do
    {shared_key} = :crypto.compute_key(:ecdh, public_key, private_key, :secp256r1)

    Logger.info("shared key: #{Base.encode16(shared_key)}")

    {:ok, shared_key}
  end
end
