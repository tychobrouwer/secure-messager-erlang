defmodule Crypt.Keys do
  @moduledoc """
  Documentation for `Keys`.

  This module provides functions for generating keys and secrets.
  """

  @type keypair :: %{public: binary, private: binary}

  @doc """
  Generates a keypair for ECDH.

  ## Examples

      iex> keypair = Crypt.Keys.generate_keypair()
      keypair
  """

  def generate_keypair do
    {public_key, private_key} = :crypto.generate_key(:eddh, :x25519)

    %{public: public_key, private: private_key}
  end

  @doc """
  Generates a shared secret from a private key and a public key.

  ## Examples

      iex> foreign_public_key = Base.decode16!("A1EAF8F96EC553733FC0636C162822AB35F1279F56A1FBB6476FD9838386931F")
      iex> private_key = Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")
      iex> {public_key, _} = :crypto.generate_key(:eddh, :x25519, private_key)
      iex> keypair = %{public: public_key, private: private_key}
      iex> shared_key = Crypt.Keys.generate_eddh_secret(keypair, foreign_public_key)
      shared_key
  """

  def generate_eddh_secret(keypair, foreign_public_key) do
    shared_key = :crypto.compute_key(:eddh, foreign_public_key, keypair.private, :x25519)

    shared_key
  end
end
