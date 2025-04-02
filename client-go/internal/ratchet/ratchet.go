package ratchet

import (
	"bytes"
	"client-go/internal/crypt"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"log"
)

type RatchetState int

const (
	Sending RatchetState = iota
	Receiving
)

type MessageRatchet struct {
	foreignPublicKey    []byte
	rootKey             []byte
	messageKey          []byte
	previousMessageKeys [][]byte
}

type DHRatchet struct {
	keyPair          crypt.KeyPair
	rootKey          []byte
	childKey         []byte
	messageRatchet   MessageRatchet
	previousRatchets []MessageRatchet
	state            RatchetState
}

func NewRatchet(keypair crypt.KeyPair, foreignPublicKey []byte) DHRatchet {
	rootKey, err := crypt.GenerateSharedSecret(keypair, foreignPublicKey)
	if err != nil {
		log.Fatalf("Failed to generate shared secret: %v", err)
	}

	messageRatchet := MessageRatchet{
		foreignPublicKey: foreignPublicKey,
	}

	return DHRatchet{
		keyPair:          keypair,
		rootKey:          rootKey,
		messageRatchet:   messageRatchet,
		previousRatchets: []MessageRatchet{},
		state:            Sending,
	}
}

func (r *DHRatchet) RKCycle(foreignPublicKey []byte) {
	dhKey, err := crypt.GenerateSharedSecret(r.keyPair, foreignPublicKey)

	if err != nil {
		log.Fatalf("Failed to generate shared secret: %v", err)
	}

	keyMaterial, err := Derive(r.rootKey, dhKey, []byte("Ratchet"), 64)

	if err != nil {
		log.Fatalf("Failed to generate key material: %v", err)
	}

	r.rootKey = keyMaterial[:32]
	r.childKey = keyMaterial[32:]
	r.previousRatchets = append(r.previousRatchets, r.messageRatchet)
	r.messageRatchet = MessageRatchet{
		rootKey:          r.rootKey,
		foreignPublicKey: foreignPublicKey,
	}
}

func (m *MessageRatchet) CKCycle() {
	keyMaterial, err := Derive(m.rootKey, nil, []byte("Chain"), 64)
	if err != nil {
		log.Fatalf("Failed to generate key material: %v", err)
	}

	m.previousMessageKeys = append(m.previousMessageKeys, m.messageKey)

	m.rootKey = keyMaterial[:32]
	m.messageKey = keyMaterial[32:]
}

func (r *DHRatchet) GetSendMRatchet() *MessageRatchet {
	if r.state == Receiving {
		newKeyPair, err := crypt.GenerateKeyPair()
		if err != nil {
			log.Fatalf("Failed to generate key pair: %v", err)
		}

		r.keyPair = newKeyPair
		r.RKCycle(r.messageRatchet.foreignPublicKey)
	}

	r.messageRatchet.CKCycle()

	return &r.messageRatchet
}

func (r *DHRatchet) GetReceiveMRatchet(foreignPublicKey []byte) (*MessageRatchet, int) {
	r.state = Receiving
	if bytes.Equal(r.messageRatchet.foreignPublicKey, foreignPublicKey) {
		return &r.messageRatchet, 0
	}

	for i, messageRatchet := range r.previousRatchets {
		if bytes.Equal(messageRatchet.foreignPublicKey, foreignPublicKey) {
			return &messageRatchet, i + 1
		}
	}

	r.RKCycle(foreignPublicKey)
	r.messageRatchet.CKCycle()

	return &r.messageRatchet, 0
}

func (m *MessageRatchet) Encrypt(plaintext []byte) ([]byte, []byte, error) {
	salt := make([]byte, 64)
	derivedKey, err := Derive(m.messageKey, salt, nil, 64)
	if err != nil {
		return nil, nil, err
	}

	encryptionKey, authenticationKey := derivedKey[:32], derivedKey[32:]

	nonce := make([]byte, 12)
	if _, err := rand.Read(nonce); err != nil {
		return nil, nil, err
	}

	ciphertext, err := crypt.EncryptAES(encryptionKey, plaintext, nonce)
	if err != nil {
		return nil, nil, err
	}

	mac := hmac.New(sha256.New, authenticationKey)
	mac.Write(append(nonce, ciphertext...))
	macHash := mac.Sum(nil)

	return append(nonce, ciphertext...), macHash, nil
}

func (m *MessageRatchet) Decrypt(ciphertext, macHash []byte) ([]byte, int, error) {
	if len(ciphertext) < 12 {
		return nil, 0, fmt.Errorf("invalid encrypted message length")
	}

	messageKey := m.messageKey

	for i := range len(m.previousMessageKeys) + 1 {
		salt := make([]byte, 64)
		derivedKey, err := Derive(messageKey, salt, nil, 64)
		if err != nil {
			return nil, 0, err
		}

		encryptionKey, authenticationKey := derivedKey[:32], derivedKey[32:]

		nonce, ciphertext := ciphertext[:12], ciphertext[12:]

		mac := hmac.New(sha256.New, authenticationKey)
		mac.Write(append(nonce, ciphertext...))
		expectedMac := mac.Sum(nil)

		if !hmac.Equal(expectedMac, macHash) {
			messageKey = m.getPrevMessageKey(i)
			continue
		}

		plaintext, err := crypt.DecryptAES(encryptionKey, ciphertext, nonce)
		if err != nil {
			return nil, 0, err
		}

		return plaintext, i, nil
	}

	return nil, 0, fmt.Errorf("failed to decrypt message")
}

func (m *MessageRatchet) getPrevMessageKey(idx int) []byte {
	if idx >= len(m.previousMessageKeys) {
		return nil
	}

	return m.previousMessageKeys[idx]
}
