package main

import (
	"client-go/internal/client"
	"client-go/internal/sqlite"
	"client-go/internal/tcpclient"
	"fmt"
	"log"
	"time"
)

func main() {
	var err error

	fmt.Println("Starting client...")

	s := tcpclient.NewTCPServer("127.0.0.1", 4040)

	db, err := sqlite.OpenDatabase("test.db")
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	} else {
		fmt.Println("Database opened successfully.")
	}

	c, err := client.NewClient(s, db)
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	} else {
		fmt.Println("Client created successfully.")
	}

	userID, password, err := sqlite.GetLoginData(db)
	if err != nil {
		fmt.Println("Signing up...")

		userID := []byte("test8")
		password := []byte("password")

		err := c.Signup(userID, password)
		if err != nil {
			log.Fatalf("Signup failed: %v", err)
		} else {
			fmt.Println("Signup successful.")
		}
	} else {
		fmt.Println("Logging in...")

		err = c.Login(userID, password)
		if err != nil {
			log.Fatalf("Login failed: %v", err)
		} else {
			fmt.Println("Login successful.")
		}
	}

	time.Sleep(1 * time.Second)

	fmt.Println("Adding a new contact...")

	err = c.AddContact([]byte("test7"))
	if err != nil {
		log.Fatalf("Failed to add contact: %v", err)
	} else {
		fmt.Println("Contact added.")
	}

	time.Sleep(1 * time.Second)

	fmt.Println("Sending a message...")

	for range 10 {
		err = c.SendMessage([]byte("test7"), []byte("Hello!"))
		if err != nil {
			log.Printf("Failed to send message: %v", err)
		} else {
			fmt.Println("Message sent.")
		}

		time.Sleep(1 * time.Second)
	}
}
