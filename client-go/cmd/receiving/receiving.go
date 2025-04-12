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

	c := client.NewClient(s)
	c.LoadKeyPair(db)
	if err != nil {
		log.Fatalf("Failed to load key pair: %v", err)
	} else {
		fmt.Println("Key pair loaded successfully.")
	}

	username, password, err := sqlite.GetLoginData(db)
	if err != nil {
		fmt.Println("Signing up...")

		username := []byte("test105")
		password := []byte("password")
		c.UpdateClient(username, password)

		err := c.Signup()
		if err != nil {
			log.Fatalf("Signup failed: %v", err)
		} else {
			fmt.Println("Signup successful.")
		}

		err = sqlite.SetLoginData(db, username, password)
		if err != nil {
			log.Fatalf("Failed to set login data: %v", err)
		}
	} else {
		c.UpdateClient(username, password)

		fmt.Println("Logging in...")

		err = c.Login()
		if err != nil {
			log.Fatalf("Login failed: %v", err)
		} else {

			fmt.Println("Login successful.")
		}
	}

	for {
		receivePayload := &client.ReceiveMessagePayload{
			StartingTimestamp: c.LastPolledTimestamp,
		}

		messages, err := c.ReceiveMessages(receivePayload)
		if err != nil {
			fmt.Printf("Failed to receive message: %v\n", err)
		}

		for i := range messages {
			fmt.Printf("Received message: %s\n", messages[i].PlainMessage())
		}

		time.Sleep(1 * time.Second)
	}
}
