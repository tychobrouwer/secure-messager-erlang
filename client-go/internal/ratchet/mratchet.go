package ratchet

import (
	"client-go/internal/crypt"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"log"
)

type MessageKey struct {
	key   []byte
	index int
}

type MessageRatchet struct {
	foreignPublicKey []byte
	rootKey          []byte
	messageKeys      []MessageKey
}

func (m *MessageRatchet) CKCycle() {
	keyMaterial, err := Derive(m.rootKey, nil, []byte("Chain"), 64)
	if err != nil {
		log.Fatalf("Failed to generate key material: %v", err)
	}

	newMessageKey := MessageKey{
		key:   keyMaterial[:32],
		index: len(m.messageKeys),
	}

	m.messageKeys = append(m.messageKeys, newMessageKey)
	m.rootKey = keyMaterial[:32]
}

func (m *MessageRatchet) Encrypt(plaintext []byte) ([]byte, []byte, int, error) {
	salt := make([]byte, 64)
	messageKey := m.getCurrentMessageKey()

	derivedKey, err := Derive(messageKey, salt, nil, 64)
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

	return append(nonce, ciphertext...), macHash, len(m.messageKeys) - 1, nil
}

func (m *MessageRatchet) getCurrentMessageKey() []byte {
	for _, messageKey := range m.messageKeys {
		if messageKey.index == len(m.messageKeys) {
			return messageKey.key
		}
	}

	return nil
}

func (m *MessageRatchet) GetMessageKey(index int) []byte {
	for _, messageKey := range m.messageKeys {
		if messageKey.index == index {
			return messageKey.key
		}
	}

	return nil
}

func (m *MessageRatchet) Decrypt(ciphertext, macHash []byte, idx int) ([]byte, error) {
	if idx < 0 {
		return nil, fmt.Errorf("invalid message key index")
	}

	if idx >= len(m.messageKeys) {
		// Generate a new message key to current index
		for i := len(m.messageKeys); i <= idx+1; i++ {
			m.CKCycle()
		}
	}

	messageKey := m.GetMessageKey(idx)
	if messageKey == nil {
		return nil, fmt.Errorf("invalid message key index")
	}

	salt := make([]byte, 64)
	derivedKey, err := Derive(messageKey, salt, nil, 64)
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
