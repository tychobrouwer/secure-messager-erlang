package client

import (
	"crypto/md5"
	"crypto/rand"

	"client-go/internal/crypt"
	"client-go/internal/tcpclient"
)

type Client struct {
	UserID    []byte
	Password  []byte
	TCPServer *tcpclient.TCPServer
	KeyPair   crypt.KeyPair
}

func NewClient(userID, password []byte, server *tcpclient.TCPServer) *Client {
	return &Client{
		UserID:    userID,
		Password:  password,
		TCPServer: server,
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

func (c *Client) AddContact(contactID string) error {
	// Implement add contact functionality
	return nil
}

func (c *Client) SendMessage(contactID, message string) error {
	// Implement send message functionality
	return nil
}
