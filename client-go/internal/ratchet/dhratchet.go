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
)

type DHRatchet struct {
	keyPair          crypt.KeyPair
	rootKey          []byte
	childKey         []byte
	messageRatchet   MessageRatchet
	previousRatchets []MessageRatchet
	state            RatchetState
}

func NewDHRatchet(keypair crypt.KeyPair, foreignPublicKey []byte) DHRatchet {
	rootKey, err := crypt.GenerateSharedSecret(keypair, foreignPublicKey)
	if err != nil {
		log.Fatalf("Failed to generate shared secret: %v", err)
	}

	messageRatchet := MessageRatchet{
		foreignPublicKey: foreignPublicKey,
		messageKeys:      []MessageKey{},
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
	if foreignPublicKey == nil {
		foreignPublicKey = r.messageRatchet.foreignPublicKey
	}

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
		messageKeys:      []MessageKey{},
	}
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
	return &r.messageRatchet
}
