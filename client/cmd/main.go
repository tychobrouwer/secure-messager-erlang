package main

import (
	"client-go/internal/client"
	"client-go/internal/gioui"
	"client-go/internal/sqlite"
	"client-go/internal/tcpclient"

	"fmt"
	"log"
	"os"

	"gioui.org/app"
)

func main() {
	var err error

	fmt.Println("Starting client...")

	s := tcpclient.NewTCPServer("127.0.0.1", 4040)

	fmt.Println("Opening database...")

	db, err := sqlite.OpenDatabase("test.db")
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}

	fmt.Println("Creating client...")

	c := client.NewClient(s, db)
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	// userID, password, err := sqlite.GetLoginData(db)
	// if err != nil {
	// 	fmt.Println("Signing up...")

	// 	userID := []byte("test7")
	// 	password := []byte("password")

	// 	err := c.Signup(userID, password)
	// 	if err != nil {
	// 		log.Fatalf("Signup failed: %v", err)
	// 	} else {
	// 		fmt.Println("Signup successful.")
	// 	}
	// } else {
	// 	fmt.Println("Logging in...")

	// 	err = c.Login(userID, password)
	// 	if err != nil {
	// 		log.Fatalf("Login failed: %v", err)
	// 	} else {
	// 		fmt.Println("Login successful.")
	// 	}
	// }

	// c.ListenIncomingMessages()

	appUI := gioui.NewApp()

	go func() {
		if err := appUI.Loop(c); err != nil {
			log.Fatal(err)
		}
		os.Exit(0)
	}()

	app.Main()
}
