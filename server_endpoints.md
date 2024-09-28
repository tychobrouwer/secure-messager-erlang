# Server Request Atoms

## :ack

General acknowledgement atom. This atom is used to acknowledge the receipt of a message.

`<<1, :ack>>`

## :error

General error atom. This atom is used to indicate that an error occurred.

`<<1, :error>>`

## :handshake (SERVER ONLY)

Handshake atom. Sent by the server to initiate a handshake with the client.

`<<1, :handshake, user_uuid::binary>>`

## :handshake_ack (CLIENT ONLY)

Handshake acknowledgement atom. Sent by the client to acknowledge the handshake.

Returns the user id of the client (ex. email, username, phone number, etc).

`<<1, :handshake_ack, user_id::binary>>`

## :message (CLIENT ONLY)

Message atom. Sent by the client to send a message to the server.

Sends the user_uuid, foreign_uuid, message_uuid, encrypted message, encryption tag, encryption hash, and public_key.

user_uuid: length 20 bytes -> Base.decode16!(user_uuid)
foreign_uuid: length 20 bytes -> Base.decode16!(foreign_uuid)
message_uuid: length 20 bytes -> Base.decode16!(Utils.uuid())
tag: length 16 bytes
hash: length 32 bytes
public_key: length 32 bytes
message: rest of the bytes

`<<1, :message, user_uuid::binary, foreign_uuid::binary, message_uuid::binary, tag::binary, hash::binary, public_key::binary, message::binary>>`

## :req_messages (CLIENT ONLY)

Request messages atom. Sent by the client to request messages from the server.

Sends the foreign_uuid and the last last_message_uuid received by the client.

`<<1, :req_messages, user_uuid::binary, foreign_uuid::binary, last_message_uuid::binary>>`

## :res_messages (SERVER ONLY)

Response messages atom. Sent by the server to send messages to the client. Can be requested by the client or pushed by the server.

Sends the user_uuid, foreign_uuid, message_uuid, encrypted message, encryption tag, encryption hash, and public_key.

`<<1, :res_messages, message_data::list>>`
