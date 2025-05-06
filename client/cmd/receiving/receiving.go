package main

import (
	"client-go/internal/client"
	"client-go/internal/sqlite"
	"client-go/internal/tcpclient"
	"fmt"
	"log"
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

	c := client.NewClient(s, db)
	err = c.LoadClientData()
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	} else {
		fmt.Println("Client created successfully.")
	}

	userID, password, err := sqlite.GetLoginData(db)
	if err != nil {
		fmt.Println("Signing up...")

		userID := []byte("test7")
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

	c.ListenIncomingMessages()

	// for {
	// 	receivePayload := &client.ReceiveMessagePayload{
	// 		StartingTimestamp: c.LastPolledTimestamp,
	// 	}

	// 	messages, err := c.RequestMessages(receivePayload)
	// 	if err != nil {
	// 		fmt.Printf("Failed to receive message: %v\n", err)
	// 	}

	// 	for i := range messages {
	// 		fmt.Printf("Received message: %s\n", messages[i].PlainMessage)
	// 	}

	// 	time.Sleep(1 * time.Second)
	// }
}
