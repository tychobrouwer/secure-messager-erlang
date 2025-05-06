package sqlite

import (
	"client-go/internal/contact/message"
	"database/sql"
)

func SaveMessage(db *sql.DB, message *message.Message) error {
	stmt, err := db.Prepare("INSERT INTO messages (thread_index, receiver_id_hash, sender_id_hash, message) VALUES (?, ?, ?, ?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	_, err = stmt.Exec(message.Header.Index, message.ReceiverIDHash, message.SenderIDHash, message.PlainMessage)
	if err != nil {
		return err
	}

	return nil
}

func GetMessages(db *sql.DB, senderID []byte) ([]*message.Message, error) {
	var messages []*message.Message

	stmt, err := db.Prepare("SELECT sender_id_hash, message FROM messages WHERE sender_id_hash = ?")
	if err != nil {
		return nil, err
	}
	defer stmt.Close()

	rows, err := stmt.Query(senderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var msg message.Message
		err = rows.Scan(&msg.SenderIDHash, &msg.PlainMessage)

		if err != nil {
			return nil, err
		}
		messages = append(messages, &msg)
	}

	return messages, nil
}
