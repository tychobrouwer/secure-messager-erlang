package main

import (
	"client-go/internal/client"
	"client-go/internal/gioui"
	"client-go/internal/gioui/icons"
	"client-go/internal/sqlite"
	"client-go/internal/tcpclient"

	"log"
	"os"

	"gioui.org/app"
)

func main() {
	var err error

	err = icons.LoadIcons()

	if err != nil {
		log.Fatalf("Failed to load icons: %v", err)
	}

	log.Printf("Starting client...")

	s := tcpclient.NewTCPServer("127.0.0.1", 4040)

	log.Printf("Opening database...")

	db, err := sqlite.OpenDatabase("test.db")
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}

	log.Printf("Creating client...")

	c := client.NewClient(s, db)
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	appUI := gioui.NewApp()

	go func() {
		if err := appUI.Loop(c); err != nil {
			log.Fatal(err)
		}
		os.Exit(0)
	}()

	app.Main()
}
