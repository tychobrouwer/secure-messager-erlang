defmodule Client do
  @moduledoc """
  Documentation for `Client`.
  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()

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
    dh_ratchet = %{root_key: root_key, child_key: nil}

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

        dh_ratchet = Crypt.Ratchet.rk_cycle(dh_ratchet, keypair, recipient_public_key)

        m_ratchet = Crypt.Ratchet.ck_cycle(dh_ratchet.child_key)

        {dh_ratchet, m_ratchet, keypair}
      else
        m_ratchet = Crypt.Ratchet.ck_cycle(m_ratchet.root_key)

        {dh_ratchet, m_ratchet, keypair}
      end

    {encrypted_message, message_tag, signature} =
      Crypt.encrypt_message(message, m_ratchet.child_key, keypair.private)

    # TODO: This should be sent to the server
    Logger.info(
      "encrpyted message send: \"#{Base.encode64(encrypted_message)}\", message tag: \"#{Base.encode64(message_tag)}\", signature: \"#{Base.encode64(signature)}\""
    )

    {dh_ratchet, m_ratchet, keypair}
  end

  @doc """
  Receive a message from a sender.
  """

  @spec receive_message(ratchet, ratchet, keypair, binary) :: {ratchet, ratchet, binary, boolean}
  def receive_message(
        dh_ratchet,
        m_ratchet,
        keypair,
        recipient_public_key
      ) do
    # TODO: This should be a message from the server
    encrypted_message = Base.decode16!("2D79EE847EA324214445EF171DCCDA40")
    message_tag = Base.decode16!("F0E2112968C85A831CB84E2CC855A142")

    # TODO: This should be a signature from the server
    signature =
      Base.decode16!(
        "747E3F4FBBEFB6B69BF16150A519890DD3BD54D7A88902101900ABC4E170C8D91EE0E460273C9413ED255EDC1F87F512F6A9E4F506F7A2BA4A1E85A6009A500F"
      )

    {dh_ratchet, m_ratchet} =
      if m_ratchet == nil do
        dh_ratchet = Crypt.Ratchet.rk_cycle(dh_ratchet, keypair, recipient_public_key)

        m_ratchet = Crypt.Ratchet.ck_cycle(dh_ratchet.child_key)

        {dh_ratchet, m_ratchet}
      else
        m_ratchet = Crypt.Ratchet.ck_cycle(m_ratchet.root_key)

        {dh_ratchet, m_ratchet}
      end

    {decrypted_message, valid} =
      Crypt.decrypt_message(
        encrypted_message,
        message_tag,
        m_ratchet.child_key,
        recipient_public_key,
        signature
      )

    {dh_ratchet, m_ratchet, decrypted_message, valid}
  end
end
