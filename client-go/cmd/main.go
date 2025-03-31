package main

import (
	"client-go/internal/client"
	"client-go/internal/tcpclient"
	"crypto/rand"
	"fmt"
	"log"
	"time"
)

func main() {
	username := make([]byte, 6)
	_, err := rand.Read(username)
	if err != nil {
		log.Fatalf("Failed to generate username: %v", err)
	}

	s := tcpclient.NewTCPServer("127.0.0.1", 4040)
	c := client.NewClient(string(username), "password", s)

	fmt.Println("Signing up...")

	err = c.Signup()
	if err != nil {
		log.Fatalf("Signup failed: %v", err)
	} else {
		fmt.Println("Signup successful.")
	}

	time.Sleep(3 * time.Second)

	fmt.Println("Logging in...")

	err = c.Login()
	if err != nil {
		log.Fatalf("Login failed: %v", err)
	} else {

		fmt.Println("Login successful.")
	}
}
