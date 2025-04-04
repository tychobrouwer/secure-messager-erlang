package main

import (
	"client-go/internal/client"
	"client-go/internal/tcpclient"
	"fmt"
	"log"
	"time"
)

func main() {
	fmt.Println("Starting client...")

	username := []byte("test9")

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

	err = c.AddContact([]byte("test1"))
	if err != nil {
		log.Fatalf("Failed to add contact: %v", err)
	} else {
		fmt.Println("Contact added.")
	}

	time.Sleep(5 * time.Second)

	fmt.Println("Sending a message...")

	err = c.SendMessage([]byte("test1"), []byte("Hello, test1!"))
	if err != nil {
		log.Printf("Failed to send message: %v", err)
	} else {
		fmt.Println("Message sent.")
	}
}
