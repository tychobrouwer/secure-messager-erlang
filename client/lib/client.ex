defmodule Client do
  @moduledoc """
  Documentation for `Client`.
  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()

  @doc """
  Starts the client.

  ## Examples

      iex> Client.start()
      :ok
  """

  @spec start() :: :ok
  def start do
    :ok
  end

  @doc """
  Initialize the client.

  ## Examples

      iex> recipient_public_key = Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")
      iex> {keypair, dh_ratchet, m_ratchet} = Client.init_client(recipient_public_key)
      {keypair, dh_ratchet, m_ratchet}
  """

  @spec init_client(binary) :: {keypair, ratchet, ratchet}
  def init_client(recipient_public_key) do
    keypair = load_keypair()

    # Initialize dh ratchet (TODO this should be 3dh ratchet method)
    root_key = Crypt.Keys.generate_eddh_secret(keypair, recipient_public_key)
    dh_ratchet = %{root_key: root_key, child_key: nil, iv_key: nil}

    # Initialize message ratchet
    m_ratchet = nil

    {keypair, dh_ratchet, m_ratchet}
  end

  @doc """
  Load a keypair for the client.

  ## Examples

      iex> keypair = Client.load_keypair()
      keypair
  """

  @spec load_keypair() :: keypair
  def load_keypair() do
    public_key =
      Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")

    private_key =
      Base.decode16!("DF2F4C61B99C25C96B55E1B5C2E04F419D8708248D196C177CF135F075ADFD60")

    %{public: public_key, private: private_key}
  end

  @doc """
  Send a message to a recipient.

  ## Examples

      iex>recipient_public_key = Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")
      iex>{keypair, dh_ratchet, m_ratchet} = Client.init_client(recipient_public_key)
      iex> {dh_ratchet, m_ratchet, enc_m} = Client.send_message("Hello, World!", dh_ratchet, m_ratchet, keypair, recipient_public_key)
      {dh_ratchet, m_ratchet, enc_m}
  """
  @spec send_message(binary, ratchet, ratchet, keypair, binary) :: {ratchet, ratchet, keypair}
  def send_message(message, dh_ratchet, m_ratchet, keypair, recipient_public_key) do
    {dh_ratchet, m_ratchet, keypair} =
      if m_ratchet == nil do
        keypair = Crypt.Keys.generate_keypair()

        dh_ratchet = Crypt.Ratchet.ratchet_init(dh_ratchet, keypair, recipient_public_key)

        m_ratchet = Crypt.Ratchet.ratchet_cycle(dh_ratchet.child_key)

        {dh_ratchet, m_ratchet, keypair}
      else
        m_ratchet = Crypt.Ratchet.ratchet_cycle(m_ratchet.root_key)

        {dh_ratchet, m_ratchet, keypair}
      end

    {encrypted_message, signature} =
      Crypt.encrypt_message(message, m_ratchet.child_key, m_ratchet.iv_key, keypair.private)

    # TODO: This should be sent to the server
    Logger.info(
      "encrpyted message send: \"#{Base.encode64(encrypted_message)}\", signature: \"#{Base.encode64(signature)}\""
    )

    {dh_ratchet, m_ratchet, keypair}
  end

  @doc """
  Receive a message from a sender.

  ## Examples

      iex>recipient_public_key = Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")
      iex>{keypair, dh_ratchet, m_ratchet} = Client.init_client(recipient_public_key)
      iex> {dh_ratchet, m_ratchet, decrypted_message, valid} = Client.receive_message(dh_ratchet, m_ratchet, keypair, recipient_public_key)
      {dh_ratchet, m_ratchet, decrypted_message, valid}
  """

  @spec receive_message(ratchet, ratchet, keypair, binary) :: {ratchet, ratchet, binary, boolean}
  def receive_message(
        dh_ratchet,
        m_ratchet,
        keypair,
        recipient_public_key
      ) do
    # TODO: This should be a message from the server
    encrypted_message = Base.decode64!("WnLgGnWxZC6k5t6TBA==")

    signature =
      Base.decode64!(
        "8bEFva25R7bKTPvtRrn7A7sLmXZ06VSrtzXWGDPU8deEOYTZRqSKPA+OeWzucOtMzaOC8ht74xmFrFrLoz+yAg=="
      )

    {dh_ratchet, m_ratchet} =
      if m_ratchet == nil do
        dh_ratchet = Crypt.Ratchet.ratchet_init(dh_ratchet, keypair, recipient_public_key)

        m_ratchet = Crypt.Ratchet.ratchet_cycle(dh_ratchet.child_key)

        {dh_ratchet, m_ratchet}
      else
        m_ratchet = Crypt.Ratchet.ratchet_cycle(m_ratchet.root_key)

        {dh_ratchet, m_ratchet}
      end

    {decrypted_message, valid} =
      Crypt.decrypt_message(
        encrypted_message,
        m_ratchet.child_key,
        m_ratchet.iv_key,
        recipient_public_key,
        signature
      )

    {dh_ratchet, m_ratchet, decrypted_message, valid}
  end
end
