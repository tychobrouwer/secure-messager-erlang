package ratchet

import (
	"client-go/internal/crypt/hkdf"
	"client-go/internal/crypt/keys"
	"log"
)

type Ratchet struct {
	KeyPair          keys.KeyPair
	foreignPublicKey []byte
	RootKey          []byte
	ChilKey          []byte
	PreviousKeys     [][]byte
	MessageKeys      [][]byte
}

func NewRatchet(keypair keys.KeyPair, foreignPublicKey []byte) Ratchet {
	rootKey, err := keys.GenerateSharedSecret(keypair, foreignPublicKey)

	if err != nil {
		log.Fatalf("Failed to generate shared secret: %v", err)
	}

	return Ratchet{
		KeyPair:          keypair,
		foreignPublicKey: foreignPublicKey,
		RootKey:          rootKey,
	}
}

func (r *Ratchet) RKCycle() {
	rootKey := r.RootKey

	dhKey, err := keys.GenerateSharedSecret(r.KeyPair, r.foreignPublicKey)

	if err != nil {
		log.Fatalf("Failed to generate shared secret: %v", err)
	}

	newRootKey, chainKey, err := KDFRK(rootKey, dhKey)

	if err != nil {
		log.Fatalf("Failed to generate root key: %v", err)
	}

	r.RootKey = newRootKey
	r.PreviousKeys = append(r.PreviousKeys, rootKey)
	r.ChilKey = chainKey
}

func (r *Ratchet) CKCycle() {
	chainKey := r.ChilKey

	newChainKey, messageKey, err := KDFCK(chainKey)

	if err != nil {
		log.Fatalf("Failed to generate chain key: %v", err)
	}

	r.ChilKey = newChainKey
	r.MessageKeys = append(r.MessageKeys, messageKey)
}

func KDFRK(rootKey, dhKey []byte) (newRootKey, chainKey []byte, err error) {
	keyMaterial, err := hkdf.Derive(rootKey, dhKey, []byte("Ratchet"), 64)

	if err != nil {
		return nil, nil, err
	}

	newRootKey = keyMaterial[:32]
	chainKey = keyMaterial[32:]

	return newRootKey, chainKey, nil
}

func KDFCK(chainKey []byte) (newChainKey, messageKey []byte, err error) {
	newChainKey, err = hkdf.Derive(chainKey, nil, []byte("Chain"), 32)

	if err != nil {
		return nil, nil, err
	}

	messageKey, err = hkdf.Derive(chainKey, nil, []byte("Message"), 32)

	if err != nil {
		return nil, nil, err
	}

	return newChainKey, messageKey, nil
}
