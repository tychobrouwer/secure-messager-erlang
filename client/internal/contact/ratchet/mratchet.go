package ratchet

import (
	"client-go/internal/crypt"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"log"
)

type MessageRatchet struct {
	ForeignPublicKey   []byte
	RootKey            []byte
	ChainKey           []byte         // Current chain key (for deriving the next keys)
	SkippedMessageKeys map[int][]byte // Keys for skipped messages
	MaxSkip            int            // Maximum number of message keys to store
	PreviousIndex      int            // Last received message index
}

func NewMessageRatchet() *MessageRatchet {
	return &MessageRatchet{
		SkippedMessageKeys: make(map[int][]byte),
		MaxSkip:            100,
		PreviousIndex:      -1,
	}
}

func (m *MessageRatchet) Initialize(rootKey, foreignPublicKey []byte) {
	m.RootKey = rootKey
	m.ForeignPublicKey = foreignPublicKey
}

// Generate the next message key and advance the chain
func (m *MessageRatchet) CKCycle() []byte {
	if m.ChainKey == nil {
		// Initialize chain key from root key if not done yet
		keyMaterial, err := derive(m.RootKey, nil, []byte("Chain"), 64)
		if err != nil {
			log.Printf("Failed to generate key material: %v", err)
			return nil
		}

		m.ChainKey = keyMaterial[32:] // Second half becomes the chain key
		return keyMaterial[:32]       // First half becomes the message key
	}

	// Normal chain key advancement
	keyMaterial, err := derive(m.ChainKey, nil, []byte("Chain"), 64)
	if err != nil {
		log.Printf("Failed to generate key material: %v", err)
		return nil
	}

	messageKey := keyMaterial[:32] // First half for encryption
	m.ChainKey = keyMaterial[32:]  // Second half for next iteration

	return messageKey
}

func (m *MessageRatchet) Encrypt(plaintext []byte) ([]byte, []byte, int, error) {
	messageKey := m.CKCycle()
	nextIndex := m.PreviousIndex + 1

	salt := make([]byte, 64)
	derivedKey, err := derive(messageKey, salt, nil, 64)
	if err != nil {
		return nil, nil, -1, err
	}

	encryptionKey, authenticationKey := derivedKey[:32], derivedKey[32:]

	nonce := make([]byte, 12)
	if _, err := rand.Read(nonce); err != nil {
		return nil, nil, -1, err
	}

	ciphertext, err := crypt.EncryptAES(encryptionKey, plaintext, nonce)
	if err != nil {
		return nil, nil, -1, err
	}

	mac := hmac.New(sha256.New, authenticationKey)
	mac.Write(append(nonce, ciphertext...))
	macHash := mac.Sum(nil)

	m.PreviousIndex = nextIndex

	return append(nonce, ciphertext...), macHash, nextIndex, nil
}

func (m *MessageRatchet) Decrypt(ciphertext, macHash []byte, msgIdx int) ([]byte, error) {
	if msgKey, exists := m.SkippedMessageKeys[msgIdx]; exists {
		defer delete(m.SkippedMessageKeys, msgIdx)

		return m.decryptWithKey(ciphertext, macHash, msgKey)
	}

	if msgIdx < 0 {
		return nil, fmt.Errorf("invalid message key index")
	}

	if msgIdx > m.PreviousIndex+1 {
		skipped := msgIdx - (m.PreviousIndex + 1)

		if skipped > m.MaxSkip {
			return nil, fmt.Errorf("too many skipped messages: %d", skipped)
		}

		for i := m.PreviousIndex + 1; i < msgIdx; i++ {
			skippedKey := m.CKCycle()
			m.SkippedMessageKeys[i] = skippedKey
		}
	}

	var messageKey []byte

	if msgIdx <= m.PreviousIndex {
		return nil, fmt.Errorf("message index already processed: %d", msgIdx)
	} else {
		messageKey = m.CKCycle()
	}

	m.PreviousIndex = msgIdx
	return m.decryptWithKey(ciphertext, macHash, messageKey)
}

func (m *MessageRatchet) decryptWithKey(ciphertext, macHash, messageKey []byte) ([]byte, error) {
	salt := make([]byte, 64)
	derivedKey, err := derive(messageKey, salt, nil, 64)
	if err != nil {
		return nil, err
	}

	encryptionKey, authenticationKey := derivedKey[:32], derivedKey[32:]

	nonce, ciphertext := ciphertext[:12], ciphertext[12:]

	mac := hmac.New(sha256.New, authenticationKey)
	mac.Write(append(nonce, ciphertext...))
	expectedMac := mac.Sum(nil)

	if !hmac.Equal(expectedMac, macHash) {
		return nil, fmt.Errorf("invalid MAC")
	}

	plaintext, err := crypt.DecryptAES(encryptionKey, ciphertext, nonce)
	if err != nil {
		return nil, err
	}

	return plaintext, nil
}
