package client

import (
  "crypto/md5"
  "crypto/rand"
  "database/sql"
  "fmt"
  "time"

  "client-go/internal/contact"
  "client-go/internal/contact/message"
  "client-go/internal/contact/ratchet"
  "client-go/internal/crypt"
  "client-go/internal/sqlite"
  "client-go/internal/tcpclient"
  "client-go/internal/utils"
)

type ReceiveMessagePayload struct {
  ContactIDHash     []byte
  StartingTimestamp int64
}

func (m *ReceiveMessagePayload) payload() []byte {
  if m.ContactIDHash == nil && m.StartingTimestamp == 0 {
    return nil
  } else if m.ContactIDHash == nil {
    return utils.IntToBytes(m.StartingTimestamp)
  } else {
    return append(m.ContactIDHash, utils.IntToBytes(m.StartingTimestamp)...)
  }
}

type Client struct {
  IDHash              []byte
  TCPServer           *tcpclient.TCPServer
  DB                  *sql.DB
  KeyPair             crypt.KeyPair
  contacts            []*contact.Contact
  LastPolledTimestamp int64
}

func NewClient(server *tcpclient.TCPServer, db *sql.DB) (*Client, error) {
  client := &Client{
    TCPServer: server,
    DB:        db,
    contacts:  []*contact.Contact{},
  }

  err := client.loadKeyPair()
  if err != nil {
    return nil, err
  }

  err = client.loadContacts()
  if err != nil {
    return nil, err
  }

  return client, nil
}

func (c *Client) loadKeyPair() error {
  keypair, err := sqlite.GetUserKeyPair(c.DB)

  if err != nil || !keypair.IsValid() {
    keypair, err = crypt.GenerateKeyPair()
    if err != nil {
      return err
    }

    err = sqlite.SetUserKeyPair(c.DB, keypair)
    if err != nil {
      return err
    }
  }

  c.KeyPair = keypair

  return nil
}

func (c *Client) Login(userID, password []byte) error {
  userIDHash := md5.Sum([]byte(userID))

  response, err := c.TCPServer.SendReceive(tcpclient.ReqKey, userIDHash[:])
  if err != nil {
    return err
  }

  nonce := make([]byte, 12)
  _, err = rand.Read(nonce)
  if err != nil {
    return err
  }

  encryptedPassword, err := crypt.EncryptAES(response.Data, password, nonce)
  if err != nil {
    return err
  }

  payload := append(userIDHash[:], nonce...)
  payload = append(payload, encryptedPassword...)

  response, err = c.TCPServer.SendReceive(tcpclient.ReqLogin, payload)
  if err != nil {
    return err
  }

  authToken, err := tcpclient.BytesToAuthToken(response.Data)
  if err != nil {
    return err
  }

  c.TCPServer.SetAuthToken(authToken)
  c.TCPServer.SetAuthID(userIDHash)
  err = sqlite.SetLoginData(c.DB, userID, password)
  if err != nil {
    return err
  }

  return nil
}

func (c *Client) Signup(userID, password []byte) error {
  userIDHash := md5.Sum([]byte(userID))

  response, err := c.TCPServer.SendReceive(tcpclient.ReqKey, userIDHash[:])
  if err != nil {
    return err
  }

  nonce := make([]byte, 12)
  _, err = rand.Read(nonce)
  if err != nil {
    return err
  }

  encryptedPassword, err := crypt.EncryptAES(response.Data, password, nonce)
  if err != nil {
    return err
  }

  payload := append(userIDHash[:], c.KeyPair.PublicKey...)
  payload = append(payload, nonce...)
  payload = append(payload, encryptedPassword...)

  response, err = c.TCPServer.SendReceive(tcpclient.ReqSignup, payload)
  if err != nil {
    return err
  }

  authToken, err := tcpclient.BytesToAuthToken(response.Data)

  if err != nil {
    return err
  }

  c.TCPServer.SetAuthToken(authToken)
  c.TCPServer.SetAuthID(userIDHash)
  err = sqlite.SetLoginData(c.DB, userID, password)
  if err != nil {
    return err
  }

  return nil
}

func (c *Client) SendMessage(contactID, plainMessage []byte) error {
  contactIDHash := md5.Sum([]byte(contactID))

  contact := contact.GetContactByIDHash(c.contacts, contactIDHash[:])
  if contact == nil {
    return fmt.Errorf("contact not found")
  }

  message := message.NewPlainMessage(c.IDHash, contact.IDHash, plainMessage)
  message.Encrypt(contact.DHRatchet)

  payload := append(contactIDHash[:], message.Payload()...)

  _, err := c.TCPServer.SendReceive(tcpclient.Message, payload)
  if err != nil {
    return err
  }

  sqlite.SaveMessage(c.DB, message)
  sqlite.UpdateContact(c.DB, contact)

  return nil
}

func (c *Client) ReceiveMessages(payloadData *ReceiveMessagePayload) ([]*message.Message, error) {
  if payloadData == nil {
    payloadData = &ReceiveMessagePayload{}
  }
  payload := payloadData.payload()

  // Get message from server
  response, err := c.TCPServer.SendReceive(tcpclient.ReqMessages, payload)
  if err != nil {
    return nil, err
  }

  c.LastPolledTimestamp = time.Now().UnixMicro()

  // No new messages
  if len(response.Data) == 0 {
    return nil, nil
  }

  if len(response.Data) < 16 {
    return nil, fmt.Errorf("invalid message format")
  }

  messages, err := message.ParseMessagesData(c.IDHash, response.Data)
  if err != nil {
    return messages, fmt.Errorf("failed to parse message data: %v", err)
  }

  failedIdxs := []int{}
  for i := range messages {
    senderIDHash := messages[i].SenderIDHash

    mContact := contact.GetContactByIDHash(c.contacts, senderIDHash)
    if mContact == nil {
      c.addContactByHash(senderIDHash, ratchet.Receiving)
      mContact = contact.GetContactByIDHash(c.contacts, senderIDHash)
    }

    // Decrypt message
    err = messages[i].Decrypt(mContact.DHRatchet)
    if err != nil {
      fmt.Printf("Failed to decrypt message: %v\n", err)

      failedIdxs = append(failedIdxs, i)
      continue
    }

    // Save decrypted message
    sqlite.SaveMessage(c.DB, messages[i])
    sqlite.UpdateContact(c.DB, mContact)
  }

  if len(failedIdxs) > 0 {
    return messages, fmt.Errorf("failed to decrypt messages at indices: %v", failedIdxs)
  }

  return messages, nil
}

func (c *Client) loadContacts() error {
  contacts, err := sqlite.GetContacts(c.DB)
  if err != nil {
    return err
  }

  for i := range contacts {
    c.contacts = append(c.contacts, &contacts[i])
  }
  return nil
}

func (c *Client) AddContact(contactID []byte) error {
  contactIDHash := md5.Sum([]byte(contactID))

  return c.addContactByHash(contactIDHash[:], ratchet.Sending)
}

func (c *Client) addContactByHash(contactIDHash []byte, initState ratchet.RatchetState) error {
  response, err := c.TCPServer.SendReceive(tcpclient.ReqPubKey, contactIDHash)
  if err != nil {
    return err
  }

  fmt.Printf("Adding contact: %x\n", contactIDHash)

  contact := contact.NewContact(contactIDHash[:], c.KeyPair, response.Data, initState)
  c.contacts = append(c.contacts, contact)

  err = sqlite.AddContact(c.DB, contactIDHash, contact.DHRatchet)
  if err != nil {
    return err
  }

  return nil
}
