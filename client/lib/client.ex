defmodule Client do
  @moduledoc """
  Documentation for `Client`.
  """

  require Logger

  @type ratchet :: %{
          root_key: binary | nil,
          child_key: binary | nil,
          iv_key: binary | nil
        }

  @doc """
  Starts the client.

  ## Examples

      iex> Client.start()
      :ok
  """

  @spec start() :: :ok
  def start do
    Logger.info("Starting client")

    private_key =
      Base.decode16!("DF2F4C61B99C25C96B55E1B5C2E04F419D8708248D196C177CF135F075ADFD60")

    public_key =
      Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")

    # Initialize dh ratchet (TODO this should be 3dh ratchet method)
    root_key = Crypt.Keys.generate_eddh_secret(private_key, public_key)
    dh_ratchet = %{root_key: root_key, child_key: nil, iv_key: nil}
    m_ratchet = nil

    {dh_ratchet, m_ratchet, enc_m_1, sign_1} =
      send_message("Hello, World!", dh_ratchet, m_ratchet, private_key, public_key)

    {dh_ratchet, m_ratchet, enc_m_2, sign_2} =
      send_message("Hello, World! 2", dh_ratchet, m_ratchet, private_key, public_key)

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
  Send a message to a recipient.

  Return
  - dh_ratchet: the DH ratchet
  - m_ratchet: the message ratchet
  - enc_m: the encrypted message
  - sign: the signature of the message

  ## Examples

      iex> {dh_ratchet, m_ratchet, enc_m, sign} = Client.send_message("Hello, World!", dh_ratchet, m_ratchet, private_key, recipient_public_key)
      {dh_ratchet, m_ratchet, enc_m, sign}
  """
  @spec send_message(binary, ratchet, ratchet, binary, binary) :: {:ok, binary, binary}
  def send_message(message, dh_ratchet, m_ratchet, private_key, recipient_public_key) do
    {dh_ratchet, m_ratchet} =
      if m_ratchet == nil do
        dh_ratchet = Crypt.Ratchet.ratchet_init(dh_ratchet, private_key, recipient_public_key)

        m_ratchet = Crypt.Ratchet.ratchet_cycle(dh_ratchet.child_key)

        {dh_ratchet, m_ratchet}
      else
        m_ratchet = Crypt.Ratchet.ratchet_cycle(m_ratchet.root_key)

        {dh_ratchet, m_ratchet}
      end

    {enc_m, sign} =
      Crypt.encrypt_message(message, m_ratchet.child_key, m_ratchet.iv_key, private_key)

    Logger.info(
      "encrpyted message send: \"#{Base.encode64(enc_m)}\", signature: \"#{Base.encode64(sign)}\""
    )

    {dh_ratchet, m_ratchet, enc_m, sign}
  end
end
