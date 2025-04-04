package message

import (
	"bytes"
	"client-go/internal/crypt"
	"client-go/internal/ratchet"
	"client-go/internal/utils"
	"fmt"
	"log"
)

type MessageHeader struct {
	publicKey []byte
	index     int
	prevCount int // Number of messages in the previous chain
}

type Message struct {
	header           MessageHeader
	encryptedMessage []byte
	plainMessage     []byte
	hash             []byte
}

func NewPlainMessage(plainMessage []byte) *Message {
	return &Message{
		plainMessage: plainMessage,
	}
}

func NewEncryptedMessage(encryptedMessage, hash, publicKey []byte, idx int) *Message {
	return &Message{
		header: MessageHeader{
			publicKey: publicKey,
			index:     idx,
			prevCount: 0,
		},
		plainMessage:     nil,
		encryptedMessage: encryptedMessage,
		hash:             hash,
	}
}

func ParseMessageData(data []byte) *Message {
	publicKey := data[:32]
	index := utils.BytesToInt(data[32:36])
	encryptedMessage := data[36 : len(data)-32] // Last 32 bytes are the hash
	hash := data[len(data)-32:]

	return &Message{
		header: MessageHeader{
			publicKey: publicKey,
			index:     index,
			prevCount: 0,
		},
		plainMessage:     nil,
		encryptedMessage: encryptedMessage,
		hash:             hash,
	}
}

func (m *Message) Encrypt(r *ratchet.DHRatchet) error {
	// if ratchet was last used for receiving
	if r.IsReceiving() {
		// generate new key pair
		newKeyPair, err := crypt.GenerateKeyPair()
		if err != nil {
			log.Fatalf("Failed to generate key pair: %v", err)
		}

		// update state to sending
		r.UpdateState(ratchet.Sending)
		// set new key pair
		r.UpdateKeyPair(newKeyPair)
		// cycle root key with current public key
		r.RKCycle(nil)
	}

	// get current message ratchet
	messageRatchet := r.GetMessageRatchet()

	// encrypt message with current message ratchet
	encryptedMessage, hash, idx, err := messageRatchet.Encrypt(m.plainMessage)
	if err != nil {
		return err
	}

	m.encryptedMessage = encryptedMessage
	m.hash = hash
	m.header.index = idx
	m.header.publicKey = r.GetPublicKey()

	return nil
}

func (m *Message) Payload() []byte {
	return append(m.header.publicKey, m.encryptedMessage...)
}

func (m *Message) Decrypt(r *ratchet.DHRatchet) error {
	// Try current ratchet first
	if r.IsCurrentRatchet(m.header.publicKey) {
		messageRatchet := r.GetMessageRatchet()
		plaintext, err := messageRatchet.Decrypt(m.encryptedMessage, m.hash, m.header.index)
		if err == nil {
			m.plainMessage = plaintext
			return nil
		}
	}

	// Try previous ratchets if current fails
	prevRatchet := r.GetPrevRatchet(m.header.publicKey)
	if prevRatchet != nil {
		plaintext, err := prevRatchet.Decrypt(m.encryptedMessage, m.hash, m.header.index)
		if err == nil {
			m.plainMessage = plaintext
			return nil
		}
	}

	if !bytes.Equal(m.header.publicKey, r.GetPublicKey()) &&
		!r.IsCurrentRatchet(m.header.publicKey) {

		// New ratchet needed
		if r.IsReceiving() {
			// Generate new keypair since we're changing direction
			newKeyPair, err := crypt.GenerateKeyPair()
			if err != nil {
				return err
			}
			r.UpdateKeyPair(newKeyPair)
		}

		// Establish new ratchet chain with the sender's public key
		r.RKCycle(m.header.publicKey)
		r.UpdateState(ratchet.Receiving)

		// Try decryption with new ratchet
		messageRatchet := r.GetMessageRatchet()
		plaintext, err := messageRatchet.Decrypt(m.encryptedMessage, m.hash, m.header.index)
		if err != nil {
			return err
		}

		m.plainMessage = plaintext
		return nil
	}

	return fmt.Errorf("failed to decrypt message: no matching ratchet")
}

func (m *Message) PlainMessage() []byte {
	return m.plainMessage
}
