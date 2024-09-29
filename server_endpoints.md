# Server Request Atoms

message_object = %{
    user_uuid: length 20 bytes
    recipient_uuid: length 20 bytes
    message_uuid: length 20 bytes
    tag: length 16 bytes
    hash: length 32 bytes
    public_key: length 32 bytes
    message: rest of the bytes
}

## :ack

General acknowledgement atom. This atom is used to acknowledge the receipt of a message.

`<<1, :ack>>`

## :error

General error atom. This atom is used to indicate that an error occurred.

`<<1, :error>>`

## :handshake (SERVER ONLY)

Handshake atom. Sent by the server to initiate a handshake with the client.

`<<1, :handshake, user_uuid>>`

## :handshake_ack (CLIENT ONLY)

Handshake acknowledgement atom. Sent by the client to acknowledge the handshake.

Returns the user id of the client (ex. email, username, phone number, etc). TODO: Authenticate the user.

<!-- ## :auth (SERVER ONLY)

Authentication atom. Sent by the server to authenticate the client.

`<<1, :handshake_ack, user_id>>` -->

## :message (CLIENT ONLY)

Message atom. Sent by the client to send a message to the server.

Sends the user_uuid, recipient_uuid, message_uuid, encrypted message, encryption tag, encryption hash, and public_key.

user_uuid: length 20 bytes -> Base.decode16!(user_uuid)
recipient_uuid: length 20 bytes -> Base.decode16!(recipient_uuid)
message_uuid: length 20 bytes -> Base.decode16!(Utils.uuid())
message_object: length unknown -> :erlang.term_to_binary(message_object)

`<<1, :message, user_uuid, recipient_uuid, message_uuid, message_object>>`

## :req_messages (CLIENT ONLY)

Request messages atom. Sent by the client to request messages from the server.

Sends the recipient_uuid and the last last_message_uuid received by the client.

user_uuid: length 20 bytes -> Base.decode16!(user_uuid)
recipient_uuid: length 20 bytes -> Base.decode16!(recipient_uuid)
last_message_uuid: length 20 bytes -> Base.decode16!(last_message_uuid)

`<<1, :req_messages, user_uuid, recipient_uuid, last_message_uuid>>`

## :res_messages (SERVER ONLY)

Response messages atom. Sent by the server to send messages to the client. Can be requested by the client or pushed by the server.

Sends the user_uuid, recipient_uuid, and a list of message_objects.

user_uuid: length 20 bytes -> Base.decode16!(user_uuid)
recipient_uuid: length 20 bytes -> Base.decode16!(recipient_uuid)
message_data: length unknown -> :erlang.term_to_binary(message_data)

`<<1, :res_messages, user_uuid, recipient_uuid, message_data::list>>`

## :req_public_key (CLIENT ONLY)

Request public key atom. Sent by the client to request the public key of a user.

user_uuid: length 20 bytes -> Base.decode16!(user_uuid)

`<<1, :req_public_key, user_uuid>>`

## :res_public_key (SERVER ONLY)

Response public key atom. Sent by the server to send the public key of a user.

Sends the user_uuid and the public_key.

user_uuid: length 20 bytes -> Base.decode16!(user_uuid)
public_key: length 32 bytes

`<<1, :res_public_key, user_uuid, public_key>>`
