package utils

const (
	PACKET_LENGTH_NR_BYTES = 4
)

func IntToBytes(i int) []byte {
	b := make([]byte, PACKET_LENGTH_NR_BYTES)
	for j := range PACKET_LENGTH_NR_BYTES {
		b[j] = byte(i >> (8 * (PACKET_LENGTH_NR_BYTES - j - 1)))
	}
	return b
}

func IntToBytesLength() int {
	return 4
}

func BytesToInt(b []byte) int {
	i := 0
	for j := range b {
		i = (i << 8) | int(b[j])
	}
	return i
}
