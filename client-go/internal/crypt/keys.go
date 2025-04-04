package crypt

import (
	"crypto/rand"

	"golang.org/x/crypto/curve25519"

	"log"
)

type KeyPair struct {
	PublicKey  []byte
	PrivateKey []byte
}

func GenerateKeyPair() (KeyPair, error) {
	priv := make([]byte, 32)
	if _, err := rand.Read(priv); err != nil {
		log.Fatalf("Failed to generate private key: %v", err)

		return KeyPair{}, err
	}

	pub, err := curve25519.X25519(priv, curve25519.Basepoint)
	if err != nil {
		log.Fatalf("Failed to generate public key: %v", err)

		return KeyPair{}, err
	}

	return KeyPair{PublicKey: pub, PrivateKey: priv}, nil
}

func GenerateSharedSecret(keypair KeyPair, publicKey []byte) ([]byte, error) {
	sharedSecret, err := curve25519.X25519(keypair.PrivateKey, publicKey)

	if err != nil {
		return nil, err
	}

	return sharedSecret, err
}
