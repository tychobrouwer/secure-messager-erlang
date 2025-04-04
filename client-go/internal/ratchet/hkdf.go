package ratchet

import (
	"crypto/hmac"
	"crypto/sha512"
	"io"
)

// Derive generates a key from input key material using HKDF.
func derive(input, salt, info []byte, length int) ([]byte, error) {
	prk := extract(input, salt)

	okm, err := expand(prk, info, length)
	if err != nil {
		return nil, err
	}

	return okm, nil
}

func extract(input, salt []byte) []byte {
	if salt == nil {
		salt = make([]byte, sha512.Size)
	}

	h := hmac.New(sha512.New, salt)
	h.Write(input)
	return h.Sum(nil)
}

func expand(prk, info []byte, length int) ([]byte, error) {
	hashLength := sha512.Size
	n := (length + hashLength - 1) / hashLength

	var okm []byte
	var previousBlock []byte

	for i := 1; i <= n; i++ {
		h := hmac.New(sha512.New, prk)
		h.Write(previousBlock)
		h.Write(info)
		h.Write([]byte{byte(i)})
		previousBlock = h.Sum(nil)
		okm = append(okm, previousBlock...)
	}

	if len(okm) < length {
		return nil, io.ErrShortBuffer
	}

	return okm[:length], nil
}
