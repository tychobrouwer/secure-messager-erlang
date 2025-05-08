package sqlite

import (
	"database/sql"

	_ "github.com/mattn/go-sqlite3" // SQLite driver
)

func OpenDatabase(source string) (*sql.DB, error) {
	// Open a database connection
	db, err := sql.Open("sqlite3", "file:"+source+"?cache=shared&mode=rwc")
	if err != nil {
		return nil, err
	}

	// Create a table
	sqlStmt := `
  CREATE TABLE IF NOT EXISTS user_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT,
    value TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(key) ON CONFLICT REPLACE
  );

  CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    thread_index INTEGER,
    receiver_id_hash BLOB,
    sender_id_hash BLOB,
    message TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(sender_id_hash) REFERENCES contacts(id_hash),
    UNIQUE(sender_id_hash, thread_index) ON CONFLICT REPLACE
  );

  CREATE TABLE IF NOT EXISTS contacts (
    id TEXT PRIMARY KEY,
    id_hash BLOB,
    ratchet BLOB,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
  `

	if _, err := db.Exec(sqlStmt); err != nil {
		return nil, err
	}

	return db, nil
}
