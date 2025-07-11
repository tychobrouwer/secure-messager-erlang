package message

import (
	"client-go/internal/contact/ratchet"
	"client-go/internal/crypt"
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
	PublicKey []byte
	Index     int
	PrevCount int // Number of messages in the previous chain
}

type Message struct {
	Header           MessageHeader
	EncryptedMessage []byte
	PlainMessage     []byte
	hash             Hash
	SenderIDHash     []byte
	ReceiverIDHash   []byte
}

func NewPlainMessage(senderIDHash, receiverIDHash, plainMessage []byte) *Message {
	return &Message{
		SenderIDHash:   senderIDHash,
		ReceiverIDHash: receiverIDHash,
		PlainMessage:   plainMessage,
	}
}

func ParseMessagesData(receiverIDHash, data []byte) ([]*Message, error) {
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

		message, err := ParseMessageData(receiverIDHash, messageData)
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

func ParseMessageData(receiverIDHash, data []byte) (*Message, error) {
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
		Header: MessageHeader{
			PublicKey: publicKey,
			Index:     index,
			PrevCount: 0,
		},
		PlainMessage:     nil,
		EncryptedMessage: encryptedMessage,
		hash:             hash,
		SenderIDHash:     senderIDHash,
		ReceiverIDHash:   receiverIDHash,
	}, nil
}

func (m *Message) Payload() []byte {
	data := make([]byte, 0, 16+len(m.Header.PublicKey)+utils.PACKET_LENGTH_NR_BYTES+len(m.EncryptedMessage)+len(m.hash))
	data = append(data, m.Header.PublicKey...)
	data = append(data, utils.IntToBytes(int64(m.Header.Index))...)
	data = append(data, m.EncryptedMessage...)
	data = append(data, hashToBytes(m.hash)...)

	return data
}

func (m *Message) Encrypt(r *ratchet.DHRatchet) error {
	// if ratchet was last used for receiving
	if !r.IsSending() {
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
	encryptedMessage, hash_bytes, idx, err := messageRatchet.Encrypt(m.PlainMessage)
	if err != nil {
		return err
	}

	hash, err := bytesToHash(hash_bytes)
	if err != nil {
		return fmt.Errorf("failed to convert bytes to hash: %v", err)
	}

	m.EncryptedMessage = encryptedMessage
	m.hash = hash
	m.Header.Index = idx
	m.Header.PublicKey = r.GetPublicKey()

	return nil
}

func (m *Message) Decrypt(r *ratchet.DHRatchet) error {
	fmt.Printf("Decrypting message\n")

	// Try current ratchet first
	if r.IsCurrentRatchet(m.Header.PublicKey) {
		fmt.Printf("Using current ratchet for decryption\n")
		messageRatchet := r.GetMessageRatchet()
		plaintext, err := messageRatchet.Decrypt(m.EncryptedMessage, hashToBytes(m.hash), m.Header.Index)
		if err == nil {
			m.PlainMessage = plaintext
		}

		return err
	}

	// Try previous ratchets if current fails
	prevRatchet := r.GetPrevRatchet(m.Header.PublicKey)
	if prevRatchet != nil {
		fmt.Printf("Using previous ratchet for decryption\n")
		plaintext, err := prevRatchet.Decrypt(m.EncryptedMessage, hashToBytes(m.hash), m.Header.Index)
		if err == nil {
			m.PlainMessage = plaintext
			return nil
		}

		return err
	}

	if !r.IsCurrentRatchet(m.Header.PublicKey) {
		fmt.Printf("No matching ratchet found, establishing new ratchet\n")

		// Establish new ratchet chain with the sender's public key
		r.RKCycle(m.Header.PublicKey)
		r.UpdateState(ratchet.Receiving)

		// Try decryption with new ratchet
		messageRatchet := r.GetMessageRatchet()
		plaintext, err := messageRatchet.Decrypt(m.EncryptedMessage, hashToBytes(m.hash), m.Header.Index)
		if err != nil {
			return err
		}

		m.PlainMessage = plaintext
		return nil
	}

	return fmt.Errorf("failed to decrypt message: no matching ratchet")
}
