# Signup and Signin Flow

## Signup

1. Client hashes username with md5
2. Client hashes password with bcrypt.
3. Client requests nonce from server.
4. Server generates a nonce and sends it to the client.
5. Client sends the hashed username, hashed password, and nonce to the server.
6. Server validates the nonce.
7. Server hashes the password with bcrypt.
8. Server stores the username and password in the database.
9. Server sends a success message to the client.

## Signin

1. Client hashes username with md5.
2. Client hashes password with bcrypt.
3. Client requests nonce from server.
4. Server generates a nonce and sends it to the client.
5. Client sends the hashed username, hashed password, and nonce to the server.
6. Server validates the nonce.
7. Server retrieves the hashed password from the database.
8. Server compares the hashed password with the one sent by the client.
9. Server sends a success message to the client.
