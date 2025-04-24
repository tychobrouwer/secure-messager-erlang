package ratchet

import (
  "bytes"
  "client-go/internal/crypt"
  "encoding/gob"
  "log"
)

type RatchetState int

const (
  Sending RatchetState = iota
  Receiving
)

type DHRatchet struct {
  KeyPair          crypt.KeyPair
  RootKey          []byte
  ChildKey         []byte
  CurrentRatchet   *MessageRatchet
  PreviousRatchets []MessageRatchet
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
    CurrentRatchet:   messageRatchet,
    PreviousRatchets: []MessageRatchet{},
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
    foreignPublicKey = r.CurrentRatchet.ForeignPublicKey
  }

  // Store current ratchet before creating a new one
  if len(r.CurrentRatchet.ForeignPublicKey) > 0 {
    r.PreviousRatchets = append(r.PreviousRatchets, *r.CurrentRatchet)

    // Limit the number of stored previous ratchets (optional)
    if len(r.PreviousRatchets) > 5 {
      r.PreviousRatchets = r.PreviousRatchets[len(r.PreviousRatchets)-5:]
    }
  }

  dhKey, err := crypt.GenerateSharedSecret(r.KeyPair, foreignPublicKey)
  if err != nil {
    log.Printf("Failed to generate shared secret: %v", err)
    return
  }

  keyMaterial, err := derive(r.RootKey, dhKey, []byte("Ratchet"), 64)
  if err != nil {
    log.Printf("Failed to generate key material: %v", err)
    return
  }

  r.RootKey = keyMaterial[:32]
  r.ChildKey = keyMaterial[32:]

  // Create a new message ratchet with proper initialization
  r.CurrentRatchet = NewMessageRatchet()
  r.CurrentRatchet.Initialize(r.RootKey, foreignPublicKey)
}

func (r *DHRatchet) IsCurrentRatchet(publicKey []byte) bool {
  return bytes.Equal(r.CurrentRatchet.ForeignPublicKey, publicKey)
}

func (r *DHRatchet) GetPrevRatchet(publicKey []byte) *MessageRatchet {
  for _, ratchet := range r.PreviousRatchets {
    if bytes.Equal(ratchet.ForeignPublicKey, publicKey) {
      return &ratchet
    }
  }

  return nil
}

func (r *DHRatchet) GetPublicKey() []byte {
  return r.KeyPair.PublicKey
}

func (r *DHRatchet) UpdateKeyPair(keypair crypt.KeyPair) {
  r.KeyPair = keypair
}

func (r *DHRatchet) UpdateState(state RatchetState) {
  r.State = state
}

func (r *DHRatchet) IsReceiving() bool {
  return r.State == Receiving
}

func (r *DHRatchet) IsSending() bool {
  return r.State == Sending
}

func (r *DHRatchet) GetMessageRatchet() *MessageRatchet {
  return r.CurrentRatchet
}
