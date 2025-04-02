package message

import (
	"client-go/internal/ratchet"
	"fmt"
)

type Message struct {
	encryptedMessage []byte
	hash             []byte
	publicKey        []byte
}

func NewMessage(encryptedMessage, hash, publicKey []byte) *Message {
	return &Message{
		encryptedMessage: encryptedMessage,
		hash:             hash,
		publicKey:        publicKey,
	}
}

func Encrypt(message []byte, key []byte) {

}

func Decrypt(messageData Message, ratchet ratchet.DHRatchet) ([]byte, error) {
	messageRatchet, idxMRatchet := ratchet.GetReceiveMRatchet(messageData.publicKey)
	if messageRatchet == nil {
		return nil, fmt.Errorf("no message ratchet found for public key")
	}

	decryptedMessage, idxMessage, err := messageRatchet.Decrypt(messageData.encryptedMessage, messageData.hash)

	if err != nil {
		return nil, err
	}

	if idxMRatchet == 0 && idxMessage == 0 {
		messageRatchet.CKCycle()
	}

	return decryptedMessage, nil
}
