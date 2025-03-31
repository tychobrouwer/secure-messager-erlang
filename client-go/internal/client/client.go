package client

import (
	"bytes"
	"crypto/aes"
	"crypto/md5"
	"fmt"

	"client-go/internal/crypt/keys"
	"client-go/internal/tcpclient"

	"golang.org/x/crypto/bcrypt"
)

type Client struct {
	UserID    string
	Password  string
	TCPServer *tcpclient.TCPServer
}

func NewClient(userID, password string, server *tcpclient.TCPServer) *Client {
	return &Client{
		UserID:    userID,
		Password:  password,
		TCPServer: server,
	}
}

func (c *Client) Login() error {
	userIDHash := md5.Sum([]byte(c.UserID))

	response, err := c.TCPServer.SendReceive(tcpclient.ReqNonce, userIDHash[:])
	if err != nil {
		return err
	}

	localSalt := "B13AAtXc39YohiOdbtiU6O"

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(c.Password+localSalt), 12)
	if err != nil {
		return err
	}

	// Pad the hashed password using PKCS7
	paddedPassword := PKCS7Pad([]byte(hashedPassword), aes.BlockSize)

	// Encrypt the password with the nonce using AES-256-ECB
	passWithNonce, err := EncryptAES256ECB(response.Data, paddedPassword)
	if err != nil {
		return err
	}

	payload := append(userIDHash[:], []byte(passWithNonce)...)

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
	localSalt := "B13AAtXc39YohiOdbtiU6O"

	keypair, err := keys.GenerateKeypair()
	if err != nil {
		return err
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(c.Password+localSalt), 12)
	if err != nil {
		return err
	}

	userIDHash := md5.Sum([]byte(c.UserID))

	payload := append(userIDHash[:], keypair.PublicKey...)
	payload = append(payload, []byte(hashedPassword)...)

	response, err := c.TCPServer.SendReceive(tcpclient.ReqSignup, payload)
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

func PKCS7Pad(data []byte, blockSize int) []byte {
	padding := blockSize - (len(data) % blockSize)
	if padding == 0 {
		padding = blockSize
	}
	padText := bytes.Repeat([]byte{byte(padding)}, padding)
	return append(data, padText...)
}

func EncryptAES256ECB(key, data []byte) (encryptedData []byte, err error) {
	if len(key) != 32 {
		return nil, fmt.Errorf("key must be 32 bytes (AES-256)")
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	if len(data)%aes.BlockSize != 0 {
		return nil, fmt.Errorf("plaintext length must be a multiple of %d bytes", aes.BlockSize)
	}

	ciphertext := make([]byte, len(data))

	for i := 0; i < len(data); i += aes.BlockSize {
		block.Encrypt(ciphertext[i:i+aes.BlockSize], data[i:i+aes.BlockSize])
	}

	return ciphertext, nil
}
