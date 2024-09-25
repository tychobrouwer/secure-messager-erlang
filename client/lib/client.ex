defmodule Client do
  @moduledoc """
  Documentation for `Client`.
  """

  require Logger

  @doc """
  Starts the client.

  ## Examples

      iex> Client.start()
      :ok
  """

  @spec start() :: :ok
  def start do
    Logger.info("Starting client")

    public_key =
      Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")

    private_key =
      Base.decode16!("DF2F4C61B99C25C96B55E1B5C2E04F419D8708248D196C177CF135F075ADFD60")

    send_message("Hello, World!", private_key, public_key)
    :ok
  end

  @doc """
  Load a keypair for the client.

  ## Examples

      iex> {private_key, public_key} = Client.load_keypair()
      {private_key, public_key}
  """

  @spec load_keypair() :: {binary, binary}
  def load_keypair() do
    public_key =
      Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")

    private_key =
      Base.decode16!("DF2F4C61B99C25C96B55E1B5C2E04F419D8708248D196C177CF135F075ADFD60")

    {private_key, public_key}
  end

  @doc """
  Send first ratchet message to a recipient.

  Return
  - r_key: the new root key
  - k_key: the new ratchet key
  - enc_m: the encrypted message
  - sign: the signature of the message

  ## Examples

      iex> {r_key, k_key, enc_m, sign} = Client.send_message("Hello, World!", r_key, private_key, recipient_public_key)
      {r_key, k_key, enc_m, sign}
  """
  @spec send_message(binary, binary, binary, binary) :: {:ok, binary, binary}
  def send_message(message, r_key, private_key, recipient_public_key) do
    {r_key, k_key, m_key, m_iv} =
      Crypt.Ratchet.ratchet_init(r_key, private_key, recipient_public_key)

    {enc_m, sign} = Crypt.encrypt_message(message, m_key, m_iv, private_key)

    {r_key, k_key, enc_m, sign}
  end

  @doc """
  Send a message to a recipient after the first ratchet message.

  Return
  - k_key: the new ratchet key
  - enc_m: the encrypted message
  - sign: the signature of the message

  ## Examples

      iex> {k_key, enc_m, sign} = Client.send_message("Hello, World!", private_key, k_key)
      {k_key, enc_m, sign}
  """
  @spec send_message(binary, binary, binary) :: {:ok, binary, binary}
  def send_message(message, private_key, k_key) do
    {r_key, m_key, m_iv} = Crypt.Ratchet.ratchet_cycle(k_key)

    {enc_m, sign} = Crypt.encrypt_message(message, m_key, m_iv, private_key)

    {r_key, enc_m, sign}
  end
end
