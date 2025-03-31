# README.md

# Secure Messager Client Go

This project is a Go implementation of a secure messaging client that interacts with a server. It provides functionalities for user authentication, contact management, and message sending.

## Project Structure

```
secure-messager-client-go
├── cmd
│   └── main.go          # Entry point of the application
├── internal
│   ├── client
│   │   ├── client.go    # Client functionality implementation
│   │   └── client_test.go # Unit tests for the client
│   └── utils
│       └── utils.go     # Utility functions
├── go.mod                # Module definition
├── go.sum                # Dependency checksums
└── README.md             # Project documentation
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