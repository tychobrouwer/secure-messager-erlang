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
  keyPair          crypt.KeyPair
  rootKey          []byte
  childKey         []byte
  currentRatchet   *MessageRatchet
  previousRatchets []MessageRatchet
  state            RatchetState
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
    keyPair:          keypair,
    rootKey:          rootKey,
    currentRatchet:   messageRatchet,
    previousRatchets: []MessageRatchet{},
    state:            initState,
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
    foreignPublicKey = r.currentRatchet.foreignPublicKey
  }

  // Store current ratchet before creating a new one
  if len(r.currentRatchet.foreignPublicKey) > 0 {
    r.previousRatchets = append(r.previousRatchets, *r.currentRatchet)

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
  r.currentRatchet = NewMessageRatchet()
  r.currentRatchet.Initialize(r.rootKey, foreignPublicKey)
}

func (r *DHRatchet) IsCurrentRatchet(publicKey []byte) bool {
  return bytes.Equal(r.currentRatchet.foreignPublicKey, publicKey)
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

func (r *DHRatchet) IsSending() bool {
  return r.state == Sending
}

func (r *DHRatchet) GetMessageRatchet() *MessageRatchet {
  return r.currentRatchet
}
