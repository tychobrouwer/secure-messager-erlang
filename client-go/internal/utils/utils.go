package utils

func IntToBytes(i int, nr_bytes int) []byte {
	b := make([]byte, nr_bytes)
	for j := 0; j < nr_bytes; j++ {
		b[j] = byte(i >> (8 * (nr_bytes - j - 1)))
	}
	return b
}

func BytesToInt(b []byte) int {
	i := 0
	for j := 0; j < len(b); j++ {
		i = (i << 8) | int(b[j])
	}
	return i
}
