package main

import (
	"client-go/internal/client"
	"client-go/internal/tcpclient"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"
)

func main() {
	args := os.Args
	if len(args) != 2 {
		fmt.Println("Usage: go run main.go <username>")
		return
	}

	fmt.Println("Starting client...")

	username := []byte(args[1])

	s := tcpclient.NewTCPServer("127.0.0.1", 4040)
	c := client.NewClient(username, []byte("password"), s)

	time.Sleep(1 * time.Second)

	fmt.Println("Signing up...")

	err := c.Signup()
	if err != nil {
		log.Fatalf("Signup failed: %v", err)
	} else {
		fmt.Println("Signup successful.")
	}

	time.Sleep(1 * time.Second)

	fmt.Println("Logging in...")

	err = c.Login()
	if err != nil {
		log.Fatalf("Login failed: %v", err)
	} else {

		fmt.Println("Login successful.")
	}

	time.Sleep(1 * time.Second)

	fmt.Println("Adding a new contact...")

	err = c.AddContact([]byte("HS0QVP"))
	if err != nil {
		log.Fatalf("Failed to add contact: %v", err)
	} else {
		fmt.Println("Contact added.")
	}

	for true {
		fmt.Println("Enter a message to send:")
		var message string
		fmt.Scanln(&message)

		if message == "exit" {
			while = false
			break
		}

		err = c.SendMessage([]byte("HS0QVP"), []byte(message))
		if err != nil {
			log.Fatalf("Failed to send message: %v", err)
		}
	}
}

const charset = "abcdefghijklmnopqrstuvwxyz" +
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

func generateUsername() string {
	b := make([]byte, 6)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return string(b)
}
