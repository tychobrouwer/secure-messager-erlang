package client

import (
	"bytes"
	"crypto/md5"
	"crypto/rand"
	"database/sql"
	"fmt"
	"strings"
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

func NewClient(server *tcpclient.TCPServer, db *sql.DB) *Client {
	return &Client{
		TCPServer: server,
		DB:        db,
		contacts:  []*contact.Contact{},
	}
}

func (c *Client) LoadClientData() error {
	err := c.loadKeyPair()
	if err != nil {
		return err
	}

	err = c.loadContacts()
	if err != nil {
		return err
	}

	return nil
}

func (c *Client) GetContactIDs() [][]byte {
	contactIDs := make([][]byte, len(c.contacts))
	for i, contact := range c.contacts {
		contactIDs[i] = contact.IDHash
	}
	return contactIDs
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
	if len(userID) == 0 {
		return fmt.Errorf("userID cannot be empty")
	}

	if len(password) == 0 {
		return fmt.Errorf("password cannot be empty")
	}

	userIDHash := md5.Sum([]byte(userID))
	c.IDHash = userIDHash[:]

	response, err := c.TCPServer.SendReceive(tcpclient.ReqKey, c.IDHash)
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

	payload := append(c.IDHash, nonce...)
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

	_, err = c.RequestMessages(nil)

	if err != nil {
		fmt.Printf("Failed to request messages: %v\n", err)
		// return err
	}

	return nil
}

func (c *Client) Signup(userID, password []byte) error {
	if len(userID) == 0 {
		return fmt.Errorf("userID cannot be empty")
	}

	if len(password) == 0 {
		return fmt.Errorf("password cannot be empty")
	}

	userIDHash := md5.Sum([]byte(userID))
	c.IDHash = userIDHash[:]

	response, err := c.TCPServer.SendReceive(tcpclient.ReqKey, c.IDHash)
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

	payload := append(c.IDHash, c.KeyPair.PublicKey...)
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

func (c *Client) ListenIncomingMessages() {
	c.TCPServer.RegisterHandler(tcpclient.RecvMessage, func(packet *tcpclient.Packet) {
		message, err := message.ParseMessageData(c.IDHash, packet.Data)
		if err != nil {
			fmt.Printf("Failed to parse incoming message: %v\n", err)
			return
		}

		fmt.Printf("Received message ListenIncomingMessages\n")

		err = c.handleIncomingMessage(message)
		if err != nil {
			fmt.Printf("Failed to handle incoming message: %v\n", err)
			return
		}
	})
}

func (c *Client) RequestMessages(payloadData *ReceiveMessagePayload) ([]*message.Message, error) {
	if payloadData == nil {
		payloadData = &ReceiveMessagePayload{}
	}
	payload := payloadData.payload()

	response, err := c.TCPServer.SendReceive(tcpclient.ReqMessages, payload)
	if err != nil {
		return nil, err
	}

	c.LastPolledTimestamp = time.Now().UnixMicro()

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
		err = c.handleIncomingMessage(messages[i])

		if err != nil {
			failedIdxs = append(failedIdxs, i)
			continue
		}
	}

	if len(failedIdxs) > 0 {
		return messages, fmt.Errorf("failed to decrypt messages at indices: %v", failedIdxs)
	}

	return messages, nil
}

func (c *Client) handleIncomingMessage(message *message.Message) error {
	senderIDHash := message.SenderIDHash

	if bytes.Equal(senderIDHash, c.IDHash) {
		senderIDHash = message.ReceiverIDHash
	}

	mContact := contact.GetContactByIDHash(c.contacts, senderIDHash)

	if mContact == nil {
		err := c.addContactByHash(senderIDHash, ratchet.Receiving)

		if err != nil {
			return err
		}

		mContact = contact.GetContactByIDHash(c.contacts, senderIDHash)
	}

	// Decrypt message
	err := message.Decrypt(mContact.DHRatchet)
	if err != nil {
		if strings.Contains(err.Error(), "message index already processed") {
			return nil
		}

		return err
	}

	// Save decrypted message
	err = sqlite.SaveMessage(c.DB, mContact.DHRatchet.RatchetIndex, message)
	if err != nil {
		return err
	}

	return sqlite.UpdateContact(c.DB, mContact)
}

func (c *Client) SendMessage(contactIDHash, plainMessage []byte) error {
	if len(contactIDHash) == 0 {
		return fmt.Errorf("contactID cannot be empty")
	}

	if len(plainMessage) == 0 {
		return fmt.Errorf("plainMessage cannot be empty")
	}

	mContact := contact.GetContactByIDHash(c.contacts, contactIDHash[:])
	if mContact == nil {
		return fmt.Errorf("contact not found")
	}

	message := message.NewPlainMessage(c.IDHash, mContact.IDHash, plainMessage)
	message.Encrypt(mContact.DHRatchet)

	payload := append(contactIDHash[:], message.Payload()...)

	_, err := c.TCPServer.SendReceive(tcpclient.SendMessage, payload)
	if err != nil {
		return err
	}

	sqlite.SaveMessage(c.DB, mContact.DHRatchet.RatchetIndex, message)
	sqlite.UpdateContact(c.DB, mContact)

	return nil
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
	if len(contactID) == 0 {
		return fmt.Errorf("contactID cannot be empty")
	}

	contactIDHash := md5.Sum([]byte(contactID))

	return c.addContactByHash(contactIDHash[:], ratchet.Sending)
}

func (c *Client) addContactByHash(contactIDHash []byte, initState ratchet.RatchetState) error {
	if len(contactIDHash) == 0 {
		return fmt.Errorf("contactIDHash cannot be empty")
	}

	for _, contact := range c.contacts {
		if bytes.Equal(contact.IDHash, contactIDHash) {
			return nil
		}
	}

	response, err := c.TCPServer.SendReceive(tcpclient.ReqPubKey, contactIDHash)
	if err != nil {
		return err
	}

	contact := contact.NewContact(contactIDHash[:], c.KeyPair, response.Data, initState)
	c.contacts = append(c.contacts, contact)

	err = sqlite.AddContact(c.DB, contactIDHash, contact.DHRatchet)
	if err != nil {
		return err
	}

	return nil
}

func (c *Client) GetContactChatHistory(contactIDHash []byte) ([]*message.Message, error) {
	if len(contactIDHash) == 0 {
		return nil, fmt.Errorf("contactIDHash cannot be empty")
	}

	mContact := contact.GetContactByIDHash(c.contacts, contactIDHash[:])
	if mContact == nil {
		return nil, fmt.Errorf("contact not found")
	}

	messages, err := sqlite.GetMessages(c.DB, contactIDHash[:])
	if err != nil {
		return nil, err
	}

	return messages, nil
}
