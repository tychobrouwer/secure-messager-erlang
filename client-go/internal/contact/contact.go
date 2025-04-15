package contact

import (
  "bytes"
  "client-go/internal/contact/ratchet"
  "client-go/internal/crypt"
)

type Contact struct {
  IDHash    []byte
  DHRatchet *ratchet.DHRatchet
}

func NewContact(IDHash []byte, keypair crypt.KeyPair, publicKey []byte, initState ratchet.RatchetState) *Contact {
  return &Contact{
    IDHash:    IDHash,
    DHRatchet: ratchet.NewDHRatchet(keypair, publicKey, initState),
  }
}

func GetContactByIDHash(contacts []*Contact, contactID []byte) *Contact {
  for i := range contacts {
    if bytes.Equal(contacts[i].IDHash, contactID) {
      return contacts[i]
    }
  }

  return nil
}
