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
	DHRatchet ratchet.DHRatchet
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

	authToken, err := tcpclient.ParseAuthToken(response.Data)
	if err != nil {
		return err
	}

	c.TCPServer.SetAuthToken(authToken)

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

	authToken, err := tcpclient.ParseAuthToken(response.Data)

	if err != nil {
		return err
	}

	c.TCPServer.SetAuthToken(authToken)
	c.TCPServer.SetAuthID(userIDHash)

	return nil
}

func (c *Client) SendMessage(contactID, plainMessage string) error {
	contact := getContactByID(c.contacts, []byte(contactID))
	if contact == nil {
		return fmt.Errorf("contact not found")
	}

	message := message.NewPlainMessage([]byte(plainMessage))
	message.Encrypt(contact.DHRatchet)

	contactIDHash := md5.Sum([]byte(contactID))

	payload := append(contactIDHash[:], message.GetPayload()...)

	_, err := c.TCPServer.SendReceive(tcpclient.Message, payload)
	if err != nil {
		return err
	}

	return nil
}

func (c *Client) ReceiveMessage() error {
	// Implement receive message functionality
	return nil
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
