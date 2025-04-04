package message

import (
	"bytes"
	"client-go/internal/crypt"
	"client-go/internal/ratchet"
	"client-go/internal/utils"
	"fmt"
	"log"
)

type Hash [32]byte

func bytesToHash(b []byte) (Hash, error) {
	if len(b) != 32 {
		return Hash{}, fmt.Errorf("invalid hash length: expected 32 bytes, got %d", len(b))
	}

	var hash Hash
	copy(hash[:], b)
	return hash, nil
}

func hashToBytes(h Hash) []byte {
	return h[:]
}

type MessageHeader struct {
	publicKey []byte
	index     int
	prevCount int // Number of messages in the previous chain
}

type Message struct {
	header           MessageHeader
	encryptedMessage []byte
	plainMessage     []byte
	hash             Hash
	senderIDHash     []byte
}

func NewPlainMessage(plainMessage []byte) *Message {
	return &Message{
		plainMessage: plainMessage,
	}
}

func NewEncryptedMessage(encryptedMessage, hash_bytes, publicKey []byte, idx int) (*Message, error) {
	hash, err := bytesToHash(hash_bytes)
	if err != nil {
		return nil, fmt.Errorf("failed to convert bytes to hash: %v", err)
	}

	return &Message{
		header: MessageHeader{
			publicKey: publicKey,
			index:     idx,
			prevCount: 0,
		},
		plainMessage:     nil,
		encryptedMessage: encryptedMessage,
		hash:             hash,
	}, nil
}

func ParseMessagesData(data []byte) ([]*Message, error) {
	var messages []*Message
	offset := 0
	i := 0

	failedIdxs := make([]int, 0)
	for offset < len(data) {
		if len(data[offset:]) < utils.PACKET_LENGTH_NR_BYTES {
			return nil, fmt.Errorf("insufficient data for message length")
		}

		messageLength := utils.BytesToInt(data[offset : offset+utils.PACKET_LENGTH_NR_BYTES])
		offset += utils.PACKET_LENGTH_NR_BYTES

		if len(data[offset:]) < messageLength {
			return messages, fmt.Errorf("insufficient data for message")
		}

		messageData := data[offset : offset+messageLength]
		offset += messageLength

		message, err := parseMessageData(messageData)
		if err != nil {
			failedIdxs = append(failedIdxs, i)
			i++
			continue
		}

		messages = append(messages, message)
		i++
	}

	if len(failedIdxs) > 0 {
		return messages, fmt.Errorf("failed to parse messages at indices: %v", failedIdxs)
	}

	return messages, nil
}

func parseMessageData(data []byte) (*Message, error) {
	offset := 0

	senderIDHash := data[offset : offset+16]
	offset += 16

	publicKey := data[offset : offset+32]
	offset += 32

	index := utils.BytesToInt(data[offset : offset+utils.PACKET_LENGTH_NR_BYTES])
	offset += utils.PACKET_LENGTH_NR_BYTES

	encryptedMessage := data[offset : len(data)-len(Hash{})]
	hash, err := bytesToHash(data[len(data)-len(Hash{}):])

	if err != nil {
		return nil, fmt.Errorf("failed to convert bytes to hash: %v", err)
	}

	return &Message{
		header: MessageHeader{
			publicKey: publicKey,
			index:     index,
			prevCount: 0,
		},
		plainMessage:     nil,
		encryptedMessage: encryptedMessage,
		hash:             hash,
		senderIDHash:     senderIDHash,
	}, nil
}

func (m *Message) SenderIDHash() []byte {
	return m.senderIDHash
}

func (m *Message) Payload() []byte {
	data := make([]byte, 0, 16+len(m.header.publicKey)+4+len(m.encryptedMessage)+len(m.hash))
	data = append(data, m.header.publicKey...)
	data = append(data, utils.IntToBytes(m.header.index)...)
	data = append(data, m.encryptedMessage...)
	data = append(data, hashToBytes(m.hash)...)

	return data
}

func (m *Message) Encrypt(r *ratchet.DHRatchet) error {
	// if ratchet was last used for receiving
	if r.IsReceiving() {
		// generate new key pair
		newKeyPair, err := crypt.GenerateKeyPair()
		if err != nil {
			log.Fatalf("Failed to generate key pair: %v", err)
		}

		// update state to sending
		r.UpdateState(ratchet.Sending)
		// set new key pair
		r.UpdateKeyPair(newKeyPair)
		// cycle root key with current public key
		r.RKCycle(nil)
	}

	// get current message ratchet
	messageRatchet := r.GetMessageRatchet()

	// encrypt message with current message ratchet
	encryptedMessage, hash_bytes, idx, err := messageRatchet.Encrypt(m.plainMessage)
	if err != nil {
		return err
	}

	hash, err := bytesToHash(hash_bytes)
	if err != nil {
		return fmt.Errorf("failed to convert bytes to hash: %v", err)
	}

	m.encryptedMessage = encryptedMessage
	m.hash = hash
	m.header.index = idx
	m.header.publicKey = r.GetPublicKey()

	return nil
}

func (m *Message) Decrypt(r *ratchet.DHRatchet) error {
	// Try current ratchet first
	if r.IsCurrentRatchet(m.header.publicKey) {
		messageRatchet := r.GetMessageRatchet()
		plaintext, err := messageRatchet.Decrypt(m.encryptedMessage, hashToBytes(m.hash), m.header.index)
		if err == nil {
			m.plainMessage = plaintext
			return nil
		}
	}

	// Try previous ratchets if current fails
	prevRatchet := r.GetPrevRatchet(m.header.publicKey)
	if prevRatchet != nil {
		plaintext, err := prevRatchet.Decrypt(m.encryptedMessage, hashToBytes(m.hash), m.header.index)
		if err == nil {
			m.plainMessage = plaintext
			return nil
		}
	}

	if !bytes.Equal(m.header.publicKey, r.GetPublicKey()) &&
		!r.IsCurrentRatchet(m.header.publicKey) {

		// New ratchet needed
		if r.IsReceiving() {
			// Generate new keypair since we're changing direction
			newKeyPair, err := crypt.GenerateKeyPair()
			if err != nil {
				return err
			}
			r.UpdateKeyPair(newKeyPair)
		}

		// Establish new ratchet chain with the sender's public key
		r.RKCycle(m.header.publicKey)
		r.UpdateState(ratchet.Receiving)

		// Try decryption with new ratchet
		messageRatchet := r.GetMessageRatchet()
		plaintext, err := messageRatchet.Decrypt(m.encryptedMessage, hashToBytes(m.hash), m.header.index)
		if err != nil {
			return err
		}

		m.plainMessage = plaintext
		return nil
	}

	return fmt.Errorf("failed to decrypt message: no matching ratchet")
}

func (m *Message) PlainMessage() []byte {
	return m.plainMessage
}
