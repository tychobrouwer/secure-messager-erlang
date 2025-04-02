package message

import (
	"client-go/internal/crypt"
	"client-go/internal/ratchet"
	"log"
)

type Message struct {
	encryptedMessage []byte
	plainMessage     []byte
	hash             []byte
	publicKey        []byte
	idx              int
}

func NewPlainMessage(plainMessage []byte) *Message {
	return &Message{
		plainMessage: plainMessage,
	}
}

func NewEncryptedMessage(encryptedMessage, hash, publicKey []byte, idx int) *Message {
	return &Message{
		encryptedMessage: encryptedMessage,
		hash:             hash,
		publicKey:        publicKey,
		idx:              idx,
	}
}

func (m *Message) Encrypt(r ratchet.DHRatchet) error {
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
	messageRatchet.CKCycle()

	// encrypt message with current message ratchet
	encryptedMessage, hash, idx, err := messageRatchet.Encrypt(m.plainMessage)
	if err != nil {
		return err
	}

	m.encryptedMessage = encryptedMessage
	m.hash = hash
	m.publicKey = r.GetPublicKey()
	m.idx = idx

	return nil
}

func (m *Message) GetPayload() []byte {
	return append(m.publicKey, m.encryptedMessage...)
}

func (m *Message) Decrypt(r ratchet.DHRatchet) error {
	// find previous ratchet with public key
	messageRatchet := r.GetPrevRatchet(m.publicKey)

	// if previous ratchet with public key is found
	if messageRatchet != nil {
		plainMessage, err := messageRatchet.Decrypt(m.encryptedMessage, m.hash, -1)
		if err != nil {
			return err
		}

		m.plainMessage = plainMessage

		return nil
	}

	// else check if public key is current ratchet
	if !r.IsCurrentRatchet(m.publicKey) {
		// if not, generate new message ratchet
		r.RKCycle(m.publicKey)
	}

	// get current message ratchet
	messageRatchet = r.GetMessageRatchet()

	// decrypt message with current message ratchet
	plainMessage, err := messageRatchet.Decrypt(m.encryptedMessage, m.hash, m.idx)
	if err != nil {
		return err
	}
	m.plainMessage = plainMessage

	r.UpdateState(ratchet.Receiving)

	return nil
}

func (m *Message) GetPlainMessage() []byte {
	return m.plainMessage
}
