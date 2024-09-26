# Encryption Flow

## Setup A

- [A] generate private and public key pair [A0]
- [A] generate private and public key pair [A1]
- [A] send public keys [A0] and [A1] to server
- [S] stores public keys

## Sending message 1 [m] from [A] to [B]

- [A] generate root key [R0] with [B0] public key and [A0] private key
- [A] Create root key [C1] from [A1] private key and [B1] public key
- [A] Create two new keys [R1] and [K1] from [R0] and [C1] with KDF
- [A] Generate new keys [K11] and [M11] from [K1]
- [A] Encrypt [m] with [M11]
- [A] Create signature of [m] with [A1] private key
- [A] Send encrypted message and signature to server
- [S] Store encrypted message and signature
- [A] Use [K1(n)] to generate new [K1(n+1)] and [M1(n+1)] keys for next messages

## Receiving message 1 [m] from [A] to [B]

- [B] Get encrypted message [m] and signature from server
- [B] Create root key [R0] with [A0] public key and [B0] private key
- [B] Create root key [C1] with [A1] public key and [B1] private key
- [B] Create two new keys [R1] and [K1] from [R0] and [C1] with KDF
- [B] Create new keys [K11] and [M11] from [K1]
- [B] Decrypt [m] with [M11]
- [B] Verify signature with [A1] public key
- [B] Use [K1(n)] to generate new [K1(n+1)] and [M1(n+1)] keys for next messages

## Sending message 2 [m] from [B] to [A]

- [A] Generate new private and public key pair [B2]
- [A] Create root key [C2] from [B2] private key and [A1] public key
- [A] Create two new keys [R2] and [K2] from [R1] and [C2] with KDF
- [A] Generate new keys [K21] and [M21] from [K2]
- [A] Encrypt [m] with [M21]
- [A] Create signature of [m] with [B2] private key
- [A] Send encrypted message and signature to server
- [S] Store encrypted message and signature
- [A] Use [K2(n)] to generate new [K2(n+1)] and [M2(n+1)] keys for next messages

## Receiving message 2 [m] from [B] to [A]

- [B] Get encrypted message [m] and signature from server
- [B] Create root key [C2] with [B2] public key and [A1] private key
- [B] Create two new keys [R2] and [K2] from [R1] and [C2] with KDF
- [B] Create new keys [K21] and [M21] from [K2]
- [B] Decrypt [m] with [M21]
- [B] Verify signature with [B2] public key
- [B] Use [K2(n)] to generate new [K2(n+1)] and [M2(n+1)] keys for next messages

## Sources

- <https://nfil.dev/coding/encryption/python/double-ratchet-example/>
- <https://excalidraw.com/>
