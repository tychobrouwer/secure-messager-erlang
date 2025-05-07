package ratchet

import (
	"bytes"
	"client-go/internal/crypt"
	"encoding/gob"
	"fmt"
	"log"
)

type RatchetState int

const PREV_RATCHET_LIMIT = 10

const (
	Sending RatchetState = iota
	Receiving
)

type DHRatchet struct {
	KeyPair          crypt.KeyPair
	RootKey          []byte
	ChildKey         []byte
	CurrentMRatchet   *MessageRatchet
	PreviousMRatchets []MessageRatchet
	RatchetIndex     int
	State            RatchetState
}

func NewDHRatchet(keypair crypt.KeyPair, foreignPublicKey []byte, initState RatchetState) *DHRatchet {
	rootKey, err := crypt.GenerateSharedSecret(keypair, foreignPublicKey)
	if err != nil {
		log.Fatalf("Failed to generate shared secret: %v", err)
	}

	messageRatchet := NewMessageRatchet()
	messageRatchet.Initialize(rootKey, foreignPublicKey)

	initGob()

	return &DHRatchet{
		KeyPair:          keypair,
		RootKey:          rootKey,
		CurrentMRatchet:   messageRatchet,
		PreviousMRatchets: []MessageRatchet{},
		RatchetIndex:     0,
		State:            initState,
	}
}

func initGob() {
	gob.Register(DHRatchet{})
	gob.Register(MessageRatchet{})
	gob.Register(crypt.KeyPair{})
}

func (r *DHRatchet) Marshal() ([]byte, error) {
	var buf bytes.Buffer
	encoder := gob.NewEncoder(&buf)

	err := encoder.Encode(r)
	return buf.Bytes(), err
}

func (r *DHRatchet) Unmarshal(data []byte) error {
	var buf bytes.Buffer
	buf.Write(data)
	decoder := gob.NewDecoder(&buf)

	return decoder.Decode(r)
}

func (r *DHRatchet) RKCycle(foreignPublicKey []byte) {
	if foreignPublicKey == nil {
	    foreignPublicKey = r.CurrentMRatchet.ForeignPublicKey
	}

	// Store current ratchet before creating a new one
	if len(r.CurrentMRatchet.ForeignPublicKey) > 0 {
		r.PreviousMRatchets = append(r.PreviousMRatchets, *r.CurrentMRatchet)

		// Limit the number of stored previous ratchets (optional)
		if len(r.PreviousRatchets) > PREV_RATCHET_LIMIT {
			r.PreviousMRatchets = r.PreviousMRatchets[len(r.PreviousMRatchets)-PREV_RATCHET_LIMIT:]
		}
	}

	dhKey, err := crypt.GenerateSharedSecret(r.KeyPair, foreignPublicKey)
	if err != nil {
		log.Printf("Failed to generate shared secret: %v", err)
		return
	}

	keyMaterial, err := derive(r.RootKey, dhKey, []byte("Ratchet"), 2*crypt.KEY_LENGTH)
	if err != nil {
		log.Printf("Failed to generate key material: %v", err)
		return
	}

	r.RootKey = keyMaterial[:crypt.KEY_LENGTH]
	r.ChildKey = keyMaterial[crypt.KEY_LENGTH:]

	// Create a new message ratchet with proper initialization
	r.CurrentMRatchet = NewMessageRatchet()
	r.CurrentMRatchet.Initialize(r.RootKey, foreignPublicKey)
	r.RatchetIndex++
}

func (r *DHRatchet) IsCurrentRatchet(publicKey []byte) bool {
	return bytes.Equal(r.CurrentMRatchet.ForeignPublicKey, publicKey)
}

func (r *DHRatchet) GetPrevRatchet(publicKey []byte) *MessageRatchet {
	fmt.Printf("Searching for previous ratchet with public key: %x\n", publicKey)

	for _, ratchet := range r.PreviousMRatchets {
		fmt.Printf("Checking public key: %x\n", ratchet.ForeignPublicKey)
		if bytes.Equal(ratchet.ForeignPublicKey, publicKey) {
			return &ratchet
		}
	}

	return nil
}
