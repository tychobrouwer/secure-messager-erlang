# Secure Messager Client Go

This project is a Go implementation of a secure messaging client that interacts with a server. It provides functionalities for user authentication, contact management, and message sending.

## Project Structure

```plain
secure-messager-client-go
├── cmd 
│   ├── sending             # Command for sending messages
│   │   └── sending.go      # Implementation of message sending
│   └── receiving           # Command for receiving messages
│       └── receiving.go    # Implementation of message receiving
│
├── internal
│   ├── client
│   │   └── client.go       # Core client functionality 
│   ├── crypt
│   │   ├── aes.go          # AES encryption/decryption
│   │   └── keys.go         # Key management
│   ├── message
│   │   └── message.go      # Message handling (encryption/decryption)
│   ├── ratchet
│   │   ├── dhratchet.go    # Diffie-Hellman Ratchet implementation
│   │   ├── hkdf.go         # HKDF key derivation function
│   │   └── mratchet.go     # Message Ratchet implementation
│   └── utils
│       └── utils.go        # Utility functions
│
├── go.mod                  # Module definition
├── go.sum                  # Dependency checksums
└── README.md               # Project documentation
```

## Installation

To get started with the project, clone the repository and navigate to the project directory:

```bash
git clone <repository-url>
cd secure-messager-client-go
```

Then, run the following command to download the necessary dependencies:

```bash
go mod tidy
```

## Usage

To run the application, execute the following command:

```bash
go run cmd/main.go
```

## Testing

To run the tests for the client functionality, use the following command:

```bash
go test ./internal/client
```

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.
