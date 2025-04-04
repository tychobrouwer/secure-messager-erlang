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

func getContactByID(contacts []Contact, contactID []byte) *Contact {
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

	keypair, err := crypt.GenerateKeyPair()
	if err != nil {
		return err
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
	contact := getContactByID(c.contacts, contactID)
	if contact == nil {
		return fmt.Errorf("contact not found")
	}

	message := message.NewPlainMessage(plainMessage)
	message.Encrypt(contact.DHRatchet)

	contactIDHash := md5.Sum([]byte(contactID))

	payload := append(contactIDHash[:], message.Payload()...)

	_, err := c.TCPServer.SendReceive(tcpclient.Message, payload)
	if err != nil {
		return err
	}

	return nil
}

func (c *Client) ReceiveMessage() ([]*message.Message, error) {
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

	fmt.Printf("Received message: %x\n", len(response.Data))

	// Extract sender ID from the response (first 16 bytes)
	senderID := response.Data[:16]
	messageData := response.Data[16:]

	// Find contact or return error
	contact := getContactByID(c.contacts, senderID)
	if contact == nil {
		return nil, fmt.Errorf("received message from unknown contact")
	}

	// Extract header information
	if len(messageData) < 36 { // Minimum size: 32 bytes for public key + 4 bytes for index
		return nil, fmt.Errorf("invalid message format")
	}

	messages, err := message.ParseMessagesData(messageData)
	if err != nil {
		return messages, fmt.Errorf("failed to parse message data: %v", err)
	}

	failedIdxs := []int{}
	for i := range messages {
		// Decrypt message
		err = messages[i].Decrypt(contact.DHRatchet)
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

func (c *Client) AddContact(contactID []byte) error {
	contactIDHash := md5.Sum([]byte(contactID))

	response, err := c.TCPServer.SendReceive(tcpclient.ReqPubKey, contactIDHash[:])
	if err != nil {
		return err
	}

	contact := Contact{
		UserID:    contactIDHash[:],
		DHRatchet: ratchet.NewDHRatchet(c.KeyPair, response.Data),
	}

	c.contacts = append(c.contacts, contact)

	return nil
}
