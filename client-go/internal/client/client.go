package client

import (
	"bytes"
	"crypto/md5"
	"crypto/rand"
	"database/sql"
	"fmt"
	"time"

	"client-go/internal/crypt"
	"client-go/internal/message"
	"client-go/internal/ratchet"
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

type Contact struct {
	UserID    []byte
	DHRatchet *ratchet.DHRatchet
}

type Client struct {
	UserID              []byte
	Password            []byte
	TCPServer           *tcpclient.TCPServer
	KeyPair             crypt.KeyPair
	LastPolledTimestamp int64
	contacts            []Contact
}

func getContactByIDHash(contacts []Contact, contactID []byte) *Contact {
	for i := range contacts {
		if bytes.Equal(contacts[i].UserID, contactID) {
			return &contacts[i]
		}
	}

	return nil
}

func NewClient(server *tcpclient.TCPServer) *Client {
	return &Client{
		TCPServer: server,
		contacts:  []Contact{},
	}
}

func (c *Client) UpdateClient(username, password []byte) *Client {
	c.UserID = username
	c.Password = password

	return c
}

func (c *Client) LoadKeyPair(db *sql.DB) error {
	keypair, err := sqlite.GetUserKeyPair(db)

	if err != nil || !keypair.IsValid() {
		keypair, err = crypt.GenerateKeyPair()
		if err != nil {
			return err
		}

		err = sqlite.SetUserKeyPair(db, keypair)
		if err != nil {
			return err
		}
	}

	c.KeyPair = keypair

	return nil
}

func (c *Client) Login() error {
	userIDHash := md5.Sum([]byte(c.UserID))

	response, err := c.TCPServer.SendReceive(tcpclient.ReqKey, userIDHash[:])
	if err != nil {
		return err
	}

	nonce := make([]byte, 12)
	_, err = rand.Read(nonce)
	if err != nil {
		return err
	}

	encryptedPassword, err := crypt.EncryptAES(response.Data, c.Password, nonce)
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

	return nil
}

func (c *Client) Signup() error {
	userIDHash := md5.Sum([]byte(c.UserID))

	response, err := c.TCPServer.SendReceive(tcpclient.ReqKey, userIDHash[:])
	if err != nil {
		return err
	}

	nonce := make([]byte, 12)
	_, err = rand.Read(nonce)
	if err != nil {
		return err
	}

	encryptedPassword, err := crypt.EncryptAES(response.Data, c.Password, nonce)
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

	return nil
}

func (c *Client) SendMessage(contactID, plainMessage []byte) error {
	contactIDHash := md5.Sum([]byte(contactID))

	contact := getContactByIDHash(c.contacts, contactIDHash[:])
	if contact == nil {
		return fmt.Errorf("contact not found")
	}

	message := message.NewPlainMessage(plainMessage)
	message.Encrypt(contact.DHRatchet)

	payload := append(contactIDHash[:], message.Payload()...)

	_, err := c.TCPServer.SendReceive(tcpclient.Message, payload)
	if err != nil {
		return err
	}

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

	messages, err := message.ParseMessagesData(response.Data)
	if err != nil {
		return messages, fmt.Errorf("failed to parse message data: %v", err)
	}

	failedIdxs := []int{}
	for i := range messages {
		senderIDHash := messages[i].SenderIDHash()

		contact := getContactByIDHash(c.contacts, senderIDHash)
		if contact == nil {
			c.AddContactByHash(senderIDHash, ratchet.Receiving)
			contact = getContactByIDHash(c.contacts, senderIDHash)
		}

		// Decrypt message
		err = messages[i].Decrypt(contact.DHRatchet)
		if err != nil {
			fmt.Printf("Failed to decrypt message: %v\n", err)

			failedIdxs = append(failedIdxs, i)
			continue
		}
	}

	if len(failedIdxs) > 0 {
		return messages, fmt.Errorf("failed to decrypt messages at indices: %v", failedIdxs)
	}

	return messages, nil

}

func (c *Client) AddContact(contactID []byte) error {
	contactIDHash := md5.Sum([]byte(contactID))

	return c.AddContactByHash(contactIDHash[:], ratchet.Sending)
}

func (c *Client) AddContactByHash(contactIDHash []byte, initState ratchet.RatchetState) error {
	response, err := c.TCPServer.SendReceive(tcpclient.ReqPubKey, contactIDHash)
	if err != nil {
		return err
	}

	fmt.Printf("Adding contact: %x\n", contactIDHash)

	contact := Contact{
		UserID:    contactIDHash[:],
		DHRatchet: ratchet.NewDHRatchet(c.KeyPair, response.Data, initState),
	}

	c.contacts = append(c.contacts, contact)

	return nil
}
