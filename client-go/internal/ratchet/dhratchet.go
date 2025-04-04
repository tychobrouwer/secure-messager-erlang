package ratchet

import (
	"bytes"
	"client-go/internal/crypt"
	"log"
)

type RatchetState int

const (
	Sending RatchetState = iota
	Receiving
	Unknown
)

type DHRatchet struct {
	keyPair          crypt.KeyPair
	rootKey          []byte
	childKey         []byte
	messageRatchet   *MessageRatchet
	previousRatchets []MessageRatchet
	state            RatchetState
}

func NewDHRatchet(keypair crypt.KeyPair, foreignPublicKey []byte) *DHRatchet {
	rootKey, err := crypt.GenerateSharedSecret(keypair, foreignPublicKey)
	if err != nil {
		log.Fatalf("Failed to generate shared secret: %v", err)
	}

	messageRatchet := NewMessageRatchet()
	messageRatchet.Initialize(rootKey, foreignPublicKey)

	return &DHRatchet{
		keyPair:          keypair,
		rootKey:          rootKey,
		messageRatchet:   messageRatchet,
		previousRatchets: []MessageRatchet{},
		state:            Unknown,
	}
}

func (r *DHRatchet) RKCycle(foreignPublicKey []byte) {
	if foreignPublicKey == nil {
		foreignPublicKey = r.messageRatchet.foreignPublicKey
	}

	// Store current ratchet before creating a new one
	if len(r.messageRatchet.foreignPublicKey) > 0 {
		r.previousRatchets = append(r.previousRatchets, *r.messageRatchet)

		// Limit the number of stored previous ratchets (optional)
		if len(r.previousRatchets) > 5 {
			r.previousRatchets = r.previousRatchets[len(r.previousRatchets)-5:]
		}
	}

	dhKey, err := crypt.GenerateSharedSecret(r.keyPair, foreignPublicKey)
	if err != nil {
		log.Printf("Failed to generate shared secret: %v", err)
		return
	}

	keyMaterial, err := derive(r.rootKey, dhKey, []byte("Ratchet"), 64)
	if err != nil {
		log.Printf("Failed to generate key material: %v", err)
		return
	}

	r.rootKey = keyMaterial[:32]
	r.childKey = keyMaterial[32:]

	// Create a new message ratchet with proper initialization
	r.messageRatchet = NewMessageRatchet()
	r.messageRatchet.Initialize(r.rootKey, foreignPublicKey)
}

func (r *DHRatchet) IsCurrentRatchet(publicKey []byte) bool {
	return bytes.Equal(r.messageRatchet.foreignPublicKey, publicKey)
}

func (r *DHRatchet) GetPrevRatchet(publicKey []byte) *MessageRatchet {
	for _, ratchet := range r.previousRatchets {
		if bytes.Equal(ratchet.foreignPublicKey, publicKey) {
			return &ratchet
		}
	}

	return nil
}

func (r *DHRatchet) GetPublicKey() []byte {
	return r.keyPair.PublicKey
}

func (r *DHRatchet) UpdateKeyPair(keypair crypt.KeyPair) {
	r.keyPair = keypair
}

func (r *DHRatchet) UpdateState(state RatchetState) {
	r.state = state
}

func (r *DHRatchet) IsReceiving() bool {
	return r.state == Receiving
}

func (r *DHRatchet) GetMessageRatchet() *MessageRatchet {
	return r.messageRatchet
}
