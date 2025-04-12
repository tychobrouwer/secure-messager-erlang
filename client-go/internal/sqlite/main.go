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
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS messages (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		sender TEXT,
		receiver TEXT,
		message TEXT,
		timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY(sender) REFERENCES contacts(id)
	);

	CREATE TABLE IF NOT EXISTS contacts (
		id TEXT PRIMARY KEY,
		name TEXT,
		public_key TEXT,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	`

	if _, err := db.Exec(sqlStmt); err != nil {
		return nil, err
	}

	return db, nil
}
