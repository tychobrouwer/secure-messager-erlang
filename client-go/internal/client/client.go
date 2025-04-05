package client

import (
	"bytes"
	"crypto/md5"
	"crypto/rand"
	"fmt"

	"client-go/internal/crypt"
	"client-go/internal/message"
	"client-go/internal/ratchet"
	"client-go/internal/tcpclient"
)

type Contact struct {
	UserID    []byte
	DHRatchet *ratchet.DHRatchet
}

type Client struct {
	UserID    []byte
	Password  []byte
	TCPServer *tcpclient.TCPServer
	KeyPair   crypt.KeyPair
	contacts  []Contact
}

func getContactByIDHash(contacts []Contact, contactID []byte) *Contact {
	for i := range contacts {
		if bytes.Equal(contacts[i].UserID, contactID) {
			return &contacts[i]
		}
	}

	return nil
}

func NewClient(userID, password []byte, server *tcpclient.TCPServer) *Client {
	return &Client{
		UserID:    userID,
		Password:  password,
		TCPServer: server,
		contacts:  []Contact{},
	}
}

func (c *Client) Login() error {
	userIDHash := md5.Sum([]byte(c.UserID))

	c.KeyPair = crypt.KeyPair{
		PublicKey:  []byte{121, 217, 135, 191, 103, 184, 203, 176, 121, 232, 253, 181, 214, 248, 167, 181, 246, 141, 205, 147, 165, 194, 165, 54, 162, 242, 253, 20, 115, 216, 248, 121},
		PrivateKey: []byte{134, 140, 111, 206, 27, 217, 225, 251, 60, 12, 176, 148, 185, 156, 25, 220, 151, 201, 163, 6, 161, 253, 169, 56, 37, 210, 188, 71, 145, 106, 78, 3},
	}

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

	// keypair, err := crypt.GenerateKeyPair()
	// if err != nil {
	// 	return err
	// }
	keypair := crypt.KeyPair{
		PublicKey:  []byte{121, 217, 135, 191, 103, 184, 203, 176, 121, 232, 253, 181, 214, 248, 167, 181, 246, 141, 205, 147, 165, 194, 165, 54, 162, 242, 253, 20, 115, 216, 248, 121},
		PrivateKey: []byte{134, 140, 111, 206, 27, 217, 225, 251, 60, 12, 176, 148, 185, 156, 25, 220, 151, 201, 163, 6, 161, 253, 169, 56, 37, 210, 188, 71, 145, 106, 78, 3},
	}

	c.KeyPair = keypair

	nonce := make([]byte, 12)
	_, err = rand.Read(nonce)
	if err != nil {
		return err
	}

	encryptedPassword, err := crypt.EncryptAES(response.Data, c.Password, nonce)
	if err != nil {
		return err
	}

	payload := append(userIDHash[:], keypair.PublicKey...)
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

func (c *Client) ReceiveMessages() ([]*message.Message, error) {
	// Get message from server
	response, err := c.TCPServer.SendReceive(tcpclient.ReqMessages, nil)
	if err != nil {
		return nil, err
	}

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
