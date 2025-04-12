package sqlite

import (
	"client-go/internal/crypt"
	"database/sql"
)

func SetUserKeyPair(db *sql.DB, keypair crypt.KeyPair) error {
	// Insert or update the user key pair in the database
	stmt, err := db.Prepare("INSERT OR REPLACE INTO user_settings (key, value) VALUES (?, ?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	_, err = stmt.Exec("public_key", keypair.PublicKey)
	if err != nil {
		return err
	}
	_, err = stmt.Exec("private_key", keypair.PrivateKey)
	if err != nil {
		return err
	}

	return nil
}

func GetUserKeyPair(db *sql.DB) (crypt.KeyPair, error) {
	var keypair crypt.KeyPair

	// Retrieve the user key pair from the database
	stmt, err := db.Prepare("SELECT value FROM user_settings WHERE key = ?")
	if err != nil {
		return keypair, err
	}
	defer stmt.Close()

	row := stmt.QueryRow("public_key")
	err = row.Scan(&keypair.PublicKey)
	if err != nil {
		return keypair, err
	}

	row = stmt.QueryRow("private_key")
	err = row.Scan(&keypair.PrivateKey)
	if err != nil {
		return keypair, err
	}

	return keypair, nil
}

func SetLoginData(db *sql.DB, username, password []byte) error {
	// Insert or update the user login data in the database
	stmt, err := db.Prepare("INSERT OR REPLACE INTO user_settings (key, value) VALUES (?, ?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	_, err = stmt.Exec("username", username)
	if err != nil {
		return err
	}
	_, err = stmt.Exec("password", password)
	if err != nil {
		return err
	}

	return nil
}

func GetLoginData(db *sql.DB) (username, password []byte, err error) {
	// Retrieve the user login data from the database
	stmt, err := db.Prepare("SELECT value FROM user_settings WHERE key = ?")
	if err != nil {
		return nil, nil, err
	}
	defer stmt.Close()

	row := stmt.QueryRow("username")
	err = row.Scan(&username)
	if err != nil {
		return nil, nil, err
	}

	row = stmt.QueryRow("password")
	err = row.Scan(&password)
	if err != nil {
		return nil, nil, err
	}

	return username, password, nil
}
