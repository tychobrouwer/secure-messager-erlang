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
	foreignPublicKey   []byte
	rootKey            []byte
	chainKey           []byte         // Current chain key (for deriving the next keys)
	skippedMessageKeys map[int][]byte // Keys for skipped messages
	maxSkip            int            // Maximum number of message keys to store
	previousIndex      int            // Last received message index
}

func NewMessageRatchet() *MessageRatchet {
	return &MessageRatchet{
		skippedMessageKeys: make(map[int][]byte),
		maxSkip:            1000, // Configurable upper limit
		previousIndex:      -1,   // Start with -1
	}
}

func (m *MessageRatchet) Initialize(rootKey, foreignPublicKey []byte) {
	m.rootKey = rootKey
	m.foreignPublicKey = foreignPublicKey
}

// Generate the next message key and advance the chain
func (m *MessageRatchet) CKCycle() []byte {
	if m.chainKey == nil {
		// Initialize chain key from root key if not done yet
		keyMaterial, err := derive(m.rootKey, nil, []byte("Chain"), 64)
		if err != nil {
			log.Printf("Failed to generate key material: %v", err)
			return nil
		}

		m.chainKey = keyMaterial[32:] // Second half becomes the chain key
		return keyMaterial[:32]       // First half becomes the message key
	}

	// Normal chain key advancement
	keyMaterial, err := derive(m.chainKey, nil, []byte("Chain"), 64)
	if err != nil {
		log.Printf("Failed to generate key material: %v", err)
		return nil
	}

	messageKey := keyMaterial[:32] // First half for encryption
	m.chainKey = keyMaterial[32:]  // Second half for next iteration

	return messageKey
}

func (m *MessageRatchet) Encrypt(plaintext []byte) ([]byte, []byte, int, error) {
	messageKey := m.CKCycle()
	nextIndex := m.previousIndex + 1

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

	m.previousIndex = nextIndex

	return append(nonce, ciphertext...), macHash, nextIndex, nil
}

func (m *MessageRatchet) Decrypt(ciphertext, macHash []byte, msgIdx int) ([]byte, error) {
	// Check if this is a skipped message key we already saved
	if msgKey, exists := m.skippedMessageKeys[msgIdx]; exists {
		// Delete after use
		defer delete(m.skippedMessageKeys, msgIdx)

		// Use the skipped message key to decrypt
		return m.decryptWithKey(ciphertext, macHash, msgKey)
	}

	// Handle new messages
	if msgIdx < 0 {
		return nil, fmt.Errorf("invalid message key index")
	}

	// If message from the future (higher index than expected)
	if msgIdx > m.previousIndex+1 {
		// Calculate how many messages were skipped
		skipped := msgIdx - (m.previousIndex + 1)

		// Enforce maximum skip limit
		if skipped > m.maxSkip {
			return nil, fmt.Errorf("too many skipped messages: %d", skipped)
		}

		// Store keys for skipped messages
		for i := m.previousIndex + 1; i < msgIdx; i++ {
			// Generate and save message keys for all skipped indices
			skippedKey := m.CKCycle()
			m.skippedMessageKeys[i] = skippedKey
		}
	}

	// Get or generate the message key for this index
	var messageKey []byte

	if msgIdx <= m.previousIndex {
		return nil, fmt.Errorf("message index already processed: %d", msgIdx)
	} else {
		// Need to advance to this index
		messageKey = m.CKCycle()
	}

	// Update previous index after successful generation
	m.previousIndex = msgIdx

	// Decrypt using the message key
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
