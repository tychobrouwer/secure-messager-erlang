package tcpclient

import (
	"fmt"
	"log"
	"net"
	"strconv"
	"sync"
	"time"
)

type TCPServer struct {
	conn      net.Conn
	authID    AuthID
	authToken AuthToken
	mu        sync.Mutex
}

// NewTCPServer creates a new TCPServer instance.
func NewTCPServer(address string, port int) *TCPServer {
	var conn net.Conn
	var err error

	retryInterval := 1 * time.Second
	maxAttempts := 10

	for attempts := 0; attempts < maxAttempts; attempts++ {
		conn, err = net.Dial("tcp", address+":"+strconv.Itoa(port))
		if err == nil {
			break
		}

		log.Printf("Failed to connect to server: %v. Retrying in %s...", err, retryInterval)
		time.Sleep(retryInterval)
		retryInterval *= 2 // Exponential backoff
	}

	if err != nil {
		log.Fatalf("Failed to connect to server after %d attempts: %v", maxAttempts, err)
	}

	// receive handshake
	buffer := make([]byte, MAX_MESSAGE_SIZE)
	_, err = conn.Read(buffer)
	if err != nil {
		log.Fatalf("Failed to read handshake: %v", err)
	}

	return &TCPServer{
		conn: conn,
	}
}

func (s *TCPServer) SendReceive(messageType MessageType, data []byte) (*Packet, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	payload, err := createPacket(messageType, data).payload(s)
	if err != nil {
		return &Packet{}, err
	}

	_, err = s.conn.Write(payload)
	if err != nil {
		return &Packet{}, err
	}

	buffer := make([]byte, 1024)
	n, err := s.conn.Read(buffer)

	if err != nil {
		return &Packet{}, err
	}

	packet, err := parsePacket(buffer[:n])

	if packet.messageType == Error {
		return &Packet{}, fmt.Errorf("server error: %s", string(packet.Data))
	}

	if err != nil {
		return &Packet{}, err
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
