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
	conn             net.Conn
	authID           AuthID
	authToken        AuthToken
	mu               sync.Mutex
	pendingResponses map[string]chan *Packet
	messageHandlers  map[MessageType]MessageHandler
	stopListener     chan struct{}
}

type MessageHandler func(*Packet)

// NewTCPServer creates a new TCPServer instance.
func NewTCPServer(address string, port int) *TCPServer {
	var conn net.Conn
	var err error

	retryInterval := 1 * time.Second
	maxAttempts := 10

	for range maxAttempts {
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

	server := &TCPServer{
		conn:             conn,
		pendingResponses: make(map[string]chan *Packet),
		messageHandlers:  make(map[MessageType]MessageHandler),
		stopListener:     make(chan struct{}),
	}

	go server.startListener()

	return server
}

func (s *TCPServer) startListener() {
	for {
		select {
		case <-s.stopListener:
			return
		default:
			buffer := make([]byte, MAX_MESSAGE_SIZE)
			n, err := s.conn.Read(buffer)

			if err != nil {
				if nerr, ok := err.(net.Error); ok && nerr.Timeout() {
					log.Printf("Read timeout: %v", err)
					continue
				}

				log.Printf("Error reading from server: %v", err)
				continue
			}

			packet, err := parsePacket(buffer[:n])
			if err != nil {
				log.Printf("Error parsing packet: %v", err)
				continue
			}

			s.mu.Lock()
			if respChan, exists := s.pendingResponses[packet.messageIDStr()]; exists {
				respChan <- packet
				delete(s.pendingResponses, packet.messageIDStr())

				s.mu.Unlock()
				continue
			}

			if handler, exists := s.messageHandlers[packet.messageType]; exists {
				s.mu.Unlock()
				handler(packet)
				continue
			}
			s.mu.Unlock()

			if packet.messageType == Error {
				log.Printf("Server error: %s", string(packet.Data))
			}

			log.Printf("No handler for message type %d", packet.messageType)
		}
	}
}

func (s *TCPServer) RegisterHandler(messageType MessageType, handler MessageHandler) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.messageHandlers[messageType] = handler
}

func (s *TCPServer) SendReceive(messageType MessageType, data []byte) (*Packet, error) {
	packet := createPacket(messageType, data)

	responseChan := make(chan *Packet)
	s.mu.Lock()
	s.pendingResponses[packet.messageIDStr()] = responseChan
	s.mu.Unlock()

	payload, err := createPacket(messageType, data).payload(s)
	if err != nil {
		return &Packet{}, err
	}

	_, err = s.conn.Write(payload)
	if err != nil {
		return &Packet{}, err
	}

	buffer := make([]byte, MAX_MESSAGE_SIZE)
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

	return err
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
	s.stopListener <- struct{}{}

	s.mu.Lock()
	defer s.mu.Unlock()
	if s.conn != nil {
		s.conn.Close()
		s.conn = nil
	}
}
