package sqlite

import (
	"client-go/internal/contact"
	"client-go/internal/contact/ratchet"
	"database/sql"
)

func GetContacts(db *sql.DB) ([]contact.Contact, error) {
	var contacts = []contact.Contact{}

	// Retrieve all contacts from the database
	stmt, err := db.Prepare("SELECT id_hash, ratchet FROM contacts")
	if err != nil {
		return nil, err
	}
	defer stmt.Close()

	rows, err := stmt.Query()
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var contactIDHash []byte
		var ratchetBytes []byte

		err = rows.Scan(&contactIDHash, &ratchetBytes)
		if err != nil {
			return nil, err
		}

		ratchet := &ratchet.DHRatchet{}
		err = ratchet.Unmarshal(ratchetBytes)
		if err != nil {
			return nil, err
		}

		contacts = append(contacts, contact.Contact{
			IDHash:    contactIDHash,
			DHRatchet: ratchet,
		})
	}

	return contacts, nil
}

func AddContact(db *sql.DB, contactIDHash []byte, ratchet *ratchet.DHRatchet) error {
	// Insert the contact ID into the contacts table
	stmt, err := db.Prepare("INSERT INTO contacts (id_hash, ratchet) VALUES (?, ?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	ratchetBytes, err := ratchet.Marshal()
	if err != nil {
		return err
	}

	_, err = stmt.Exec(contactIDHash, ratchetBytes)
	if err != nil {
		return err
	}

	return nil
}

func UpdateContact(db *sql.DB, c *contact.Contact) error {
	// Update the contact ID in the contacts table
	stmt, err := db.Prepare("UPDATE contacts SET ratchet = ? WHERE id_hash = ?")
	if err != nil {
		return err
	}
	defer stmt.Close()

	ratchetBytes, err := c.DHRatchet.Marshal()
	if err != nil {
		return err
	}

	_, err = stmt.Exec(ratchetBytes, c.IDHash)
	if err != nil {
		return err
	}

	return nil
}
