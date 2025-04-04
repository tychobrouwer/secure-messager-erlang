package tcpclient

import (
	"client-go/internal/utils"
	"crypto/rand"
	"fmt"
)

type MessageType int
type MessageID [16]byte
type AuthID [16]byte
type AuthToken [32]byte

const (
	Ack MessageType = iota
	Error
	Handshake
	ReqLogin
	ResLogin
	ReqSignup
	ResSignup
	ReqLogout
	ResLogout
	ReqKey
	ResKey
	Message
	ReqMessages
	ResMessages
	ReqPubKey
	ResPubKey
)

type Packet struct {
	version     int
	messageType MessageType
	messageID   MessageID
	Data        []byte
}

const (
	MAX_MESSAGE_SIZE = 1024
)

func (p Packet) payload(s *TCPServer) ([]byte, error) {
	if len(p.Data) > MAX_MESSAGE_SIZE {
		return nil, fmt.Errorf("data length exceeds maximum: %d", len(p.Data))
	}

	message := append([]byte{}, byte(p.version))
	message = append(message, byte(p.messageType))
	message = append(message, p.messageID[:]...)

	if p.messageType != ReqKey && p.messageType != ReqLogin && p.messageType != ReqSignup {
		if s.authID == (AuthID{}) || s.authToken == (AuthToken{}) {
			return nil, fmt.Errorf("authID or authToken not set")
		}

		message = append(message, s.authID[:]...)
		message = append(message, s.authToken[:]...)
	}

	message = append(message, p.Data...)

	length := len(message)
	message = append(utils.IntToBytes(length, 4), message...)
	return message, nil
}

func createPacket(messageType MessageType, data []byte) *Packet {
	messageID := MessageID{}
	rand.Read(messageID[:])

	return &Packet{
		version:     1,
		messageType: messageType,
		messageID:   messageID,
		Data:        data,
	}
}

func parsePacket(data []byte) (*Packet, error) {
	if len(data) < 22 {
		return &Packet{}, fmt.Errorf("invalid packet length")
	}

	packet := &Packet{
		version:     int(data[4]),
		messageType: MessageType(data[5]),
		messageID:   MessageID{},
		Data:        data[22:],
	}

	copy(packet.messageID[:], data[6:22])

	return packet, nil
}

func ParseAuthToken(data []byte) (AuthToken, error) {
	if len(data) != len(AuthToken{}) {
		return AuthToken{}, fmt.Errorf("invalid auth token length")
	}

	token := AuthToken{}
	copy(token[:], data)
	return token, nil
}

func ParseAuthID(data []byte) (AuthID, error) {
	if len(data) != len(AuthID{}) {
		return AuthID{}, fmt.Errorf("invalid auth ID length")
	}

	authID := AuthID{}
	copy(authID[:], data)
	return authID, nil
}
