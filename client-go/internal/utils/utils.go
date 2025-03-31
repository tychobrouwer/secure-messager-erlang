package utils

import (
	"regexp"
)

// IsValidEmail checks if the provided email is valid.
func IsValidEmail(email string) bool {
	const emailRegex = `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
	re := regexp.MustCompile(emailRegex)
	return re.MatchString(email)
}

// IsValidPassword checks if the provided password meets the criteria.
func IsValidPassword(password string) bool {
	return len(password) >= 8
}
