package tcpclient

import (
	"crypto/rand"
	"fmt"
	"log"
	"net"
	"strconv"
	"sync"
)

type MessageType int

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

type MessageID [16]byte
type AuthID [16]byte
type AuthToken [32]byte

type Packet struct {
	version     int
	messageType MessageType
	messageID   MessageID
	Data        []byte
}

func (p Packet) Bytes(s *TCPServer) []byte {
	if p.messageType == ReqKey || p.messageType == ReqLogin || p.messageType == ReqSignup {
		message := append([]byte{}, byte(p.version))
		message = append(message, byte(p.messageType))
		message = append(message, p.messageID[:]...)
		message = append(message, p.Data...)

		return message
	} else {
		message := append([]byte{}, byte(p.version))
		message = append(message, byte(p.messageType))
		message = append(message, p.messageID[:]...)
		message = append(message, s.authID[:]...)
		message = append(message, s.authToken[:]...)
		message = append(message, p.Data...)

		return message
	}
}

type TCPServer struct {
	conn      net.Conn
	authID    AuthID
	authToken AuthToken
	mu        sync.Mutex
}

// NewTCPServer creates a new TCPServer instance.
func NewTCPServer(address string, port int) *TCPServer {
	conn, err := net.Dial("tcp", address+":"+strconv.Itoa(port))
	if err != nil {
		log.Fatalf("Failed to connect to server: %v", err)
	}

	// receive handshake
	buffer := make([]byte, 1024)
	_, err = conn.Read(buffer)
	if err != nil {
		log.Fatalf("Failed to read handshake: %v", err)
	}

	return &TCPServer{
		conn: conn,
	}
}

func (s *TCPServer) SendReceive(messageType MessageType, data []byte) (Packet, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	packet := createPacket(messageType, data)

	length := len(packet.Bytes(s))

	payload := append([]byte{}, byte(length>>24), byte(length>>16), byte(length>>8), byte(length))
	payload = append(payload, packet.Bytes(s)...)

	_, err := s.conn.Write(payload)
	if err != nil {
		return Packet{}, err
	}

	buffer := make([]byte, 1024)
	n, err := s.conn.Read(buffer)

	if err != nil {
		return Packet{}, err
	}

	packet, err = ParsePacket(buffer[:n])

	if packet.messageType == Error {
		return Packet{}, fmt.Errorf("server error: %s", string(packet.Data))
	}

	if err != nil {
		return Packet{}, err
	}

	return packet, nil
}

func (s *TCPServer) SetAuthToken(token AuthToken) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.authToken = token
}

func (s *TCPServer) SetAuthID(authID AuthID) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.authID = authID
}

func (s *TCPServer) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.conn.Close()
}

func createPacket(messageType MessageType, data []byte) Packet {
	messageID := MessageID{}
	rand.Read(messageID[:])

	packet := Packet{
		version:     1,
		messageType: messageType,
		messageID:   messageID,
		Data:        data,
	}

	return packet
}

func ParsePacket(data []byte) (Packet, error) {
	if len(data) < 18 {
		return Packet{}, fmt.Errorf("invalid packet length")
	}

	packet := Packet{
		version:     int(data[4]),
		messageType: MessageType(data[5]),
		Data:        data[22:],
	}

	copy(packet.messageID[:], data[5:21])

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
