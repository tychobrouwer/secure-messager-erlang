package utils

const (
  PACKET_LENGTH_NR_BYTES = 8
)

func IntToBytes(i int64) []byte {
  b := make([]byte, PACKET_LENGTH_NR_BYTES)
  for j := range PACKET_LENGTH_NR_BYTES {
    b[j] = byte(i >> (8 * (PACKET_LENGTH_NR_BYTES - j - 1)))
  }

  return b
}

func BytesToInt(b []byte) int {
  i := 0
  for j := range b {
    i = (i << 8) | int(b[j])
  }
  return i
}
