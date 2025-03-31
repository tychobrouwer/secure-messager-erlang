package message

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"fmt"

	"client-go/internal/crypt/hkdf"
)

func EncryptMessage(message []byte, key []byte) (encryptedMessage, macHash []byte, err error) {
	salt := make([]byte, 64) // 80 bytes of zero-filled salt
	derivedKey, err := hkdf.Derive(key, salt, nil, 64)

	if err != nil {
		return nil, nil, err
	}

	encryptionKey := derivedKey[:32]
	authenticationKey := derivedKey[32:]

	iv := make([]byte, 12)
	if _, err := rand.Read(iv); err != nil {
		return nil, nil, err
	}

	block, err := aes.NewCipher(encryptionKey)
	if err != nil {
		return nil, nil, err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, nil, err
	}

	associatedData := []byte("")
	encryptedMessage = aesGCM.Seal(nil, iv, message, associatedData)

	mac := hmac.New(sha256.New, authenticationKey)
	mac.Write(append(iv, encryptedMessage...))
	macHash = mac.Sum(nil)

	return append(iv, encryptedMessage...), macHash, nil
}

func DecryptMessage(encryptedMessage, hash, key []byte) (message []byte, err error) {
	if len(encryptedMessage) < 12 {
		return nil, fmt.Errorf("invalid encrypted message length")
	}

	iv := encryptedMessage[:12]
	encryptedMessage = encryptedMessage[12:]

	salt := make([]byte, 64)
	derivedKey, err := hkdf.Derive(key, salt, nil, 64)

	if err != nil {
		return nil, err
	}

	encryptionKey := derivedKey[:32]
	authenticationKey := derivedKey[32:]

	mac := hmac.New(sha256.New, authenticationKey)
	mac.Write(append(iv, encryptedMessage...))
	macHash := mac.Sum(nil)

	if !hmac.Equal(macHash, hash) {
		return nil, fmt.Errorf("invalid hash")
	}

	block, err := aes.NewCipher(encryptionKey)
	if err != nil {
		return nil, err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	associatedData := []byte("")
	message, err = aesGCM.Open(nil, iv, encryptedMessage, associatedData)

	if err != nil {
		return nil, err
	}

	return message, nil
}
