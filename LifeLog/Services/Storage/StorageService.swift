import Foundation
import SQLite3

/// Service responsible for data persistence
actor StorageService {
    static let shared = StorageService()

    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        // Store database in Application Support
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDir = appSupport.appendingPathComponent("LifeLog")

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: appDir,
            withIntermediateDirectories: true
        )

        self.dbPath = appDir.appendingPathComponent("lifelog.db").path

        Task {
            await initializeDatabase()
        }
    }

    // MARK: - Initialization

    private func initializeDatabase() async {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            Logger.error("Failed to open database at \(dbPath)", log: Logger.storage)
            return
        }

        Logger.log("Database opened at \(dbPath)", log: Logger.storage)

        // Create tables
        await createTables()
    }

    private func createTables() async {
        let schema = """
        -- Captures table
        CREATE TABLE IF NOT EXISTS captures (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            screen_hash TEXT UNIQUE NOT NULL,
            image_path TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_captures_timestamp ON captures(timestamp);
        CREATE INDEX IF NOT EXISTS idx_captures_hash ON captures(screen_hash);

        -- Text entries table
        CREATE TABLE IF NOT EXISTS text_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            capture_id INTEGER,
            timestamp INTEGER NOT NULL,
            raw_text TEXT NOT NULL,
            confidence REAL,
            app_name TEXT,
            window_title TEXT,
            screen_region TEXT,
            FOREIGN KEY(capture_id) REFERENCES captures(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_text_entries_timestamp ON text_entries(timestamp);
        CREATE INDEX IF NOT EXISTS idx_text_entries_app ON text_entries(app_name);

        -- Full-text search index
        CREATE VIRTUAL TABLE IF NOT EXISTS text_entries_fts USING fts5(
            raw_text,
            app_name,
            content=text_entries,
            content_rowid=id
        );

        -- Triggers to keep FTS index in sync
        CREATE TRIGGER IF NOT EXISTS text_entries_ai AFTER INSERT ON text_entries BEGIN
            INSERT INTO text_entries_fts(rowid, raw_text, app_name)
            VALUES (new.id, new.raw_text, new.app_name);
        END;

        CREATE TRIGGER IF NOT EXISTS text_entries_ad AFTER DELETE ON text_entries BEGIN
            DELETE FROM text_entries_fts WHERE rowid = old.id;
        END;

        CREATE TRIGGER IF NOT EXISTS text_entries_au AFTER UPDATE ON text_entries BEGIN
            DELETE FROM text_entries_fts WHERE rowid = old.id;
            INSERT INTO text_entries_fts(rowid, raw_text, app_name)
            VALUES (new.id, new.raw_text, new.app_name);
        END;

        -- Summaries table
        CREATE TABLE IF NOT EXISTS summaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time INTEGER NOT NULL,
            end_time INTEGER NOT NULL,
            summary TEXT NOT NULL,
            keywords TEXT,
            activity_type TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_summaries_time ON summaries(start_time, end_time);

        -- Query log table
        CREATE TABLE IF NOT EXISTS query_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            query TEXT NOT NULL,
            response TEXT NOT NULL,
            context_used TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_query_log_timestamp ON query_log(timestamp);
        """

        for statement in schema.components(separatedBy: ";") {
            let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if sqlite3_exec(db, trimmed, nil, nil, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                Logger.error("SQL error: \(error)", log: Logger.storage)
            }
        }

        Logger.log("Database schema initialized", log: Logger.storage)
    }

    // MARK: - Captures

    func saveCapture(_ capture: Capture) async -> Int64 {
        let sql = """
        INSERT INTO captures (timestamp, screen_hash, image_path)
        VALUES (?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare capture insert", log: Logger.storage)
            return 0
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(capture.timestamp.timeIntervalSince1970))
        sqlite3_bind_text(statement, 2, (capture.screenHash as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (capture.imagePath as NSString?)?.utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_DONE {
            let captureId = sqlite3_last_insert_rowid(db)
            Logger.log("Saved capture with ID \(captureId)", log: Logger.storage, type: .debug)
            return captureId
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            Logger.error("Failed to save capture: \(error)", log: Logger.storage)
            return 0
        }
    }

    // MARK: - Text Entries

    func saveTextEntry(_ entry: TextEntry) async {
        let sql = """
        INSERT INTO text_entries (capture_id, timestamp, raw_text, confidence, app_name, window_title)
        VALUES (?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare text entry insert", log: Logger.storage)
            return
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, entry.captureId)
        sqlite3_bind_int64(statement, 2, Int64(entry.timestamp.timeIntervalSince1970))
        sqlite3_bind_text(statement, 3, (entry.rawText as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 4, Double(entry.confidence))
        sqlite3_bind_text(statement, 5, (entry.appName as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_text(statement, 6, (entry.windowTitle as NSString?)?.utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_DONE {
            Logger.log("Saved text entry", log: Logger.storage, type: .debug)
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            Logger.error("Failed to save text entry: \(error)", log: Logger.storage)
        }
    }

    // MARK: - Full-Text Search

    func searchText(_ query: String, limit: Int = 50) async -> [TextEntry] {
        let sql = """
        SELECT te.id, te.capture_id, te.timestamp, te.raw_text, te.confidence, te.app_name, te.window_title
        FROM text_entries te
        JOIN text_entries_fts fts ON te.id = fts.rowid
        WHERE text_entries_fts MATCH ?
        ORDER BY te.timestamp DESC
        LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare search query", log: Logger.storage)
            return []
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (query as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var results: [TextEntry] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let entry = TextEntry(
                id: sqlite3_column_int64(statement, 0),
                captureId: sqlite3_column_int64(statement, 1),
                timestamp: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2))),
                rawText: String(cString: sqlite3_column_text(statement, 3)),
                confidence: Float(sqlite3_column_double(statement, 4)),
                appName: sqlite3_column_text(statement, 5).map { String(cString: $0) },
                windowTitle: sqlite3_column_text(statement, 6).map { String(cString: $0) }
            )
            results.append(entry)
        }

        return results
    }

    // MARK: - Time-based Queries

    func getEntriesBetween(start: Date, end: Date) async -> [TextEntry] {
        let sql = """
        SELECT id, capture_id, timestamp, raw_text, confidence, app_name, window_title
        FROM text_entries
        WHERE timestamp BETWEEN ? AND ?
        ORDER BY timestamp ASC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(start.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, Int64(end.timeIntervalSince1970))

        var results: [TextEntry] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let entry = TextEntry(
                id: sqlite3_column_int64(statement, 0),
                captureId: sqlite3_column_int64(statement, 1),
                timestamp: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2))),
                rawText: String(cString: sqlite3_column_text(statement, 3)),
                confidence: Float(sqlite3_column_double(statement, 4)),
                appName: sqlite3_column_text(statement, 5).map { String(cString: $0) },
                windowTitle: sqlite3_column_text(statement, 6).map { String(cString: $0) }
            )
            results.append(entry)
        }

        return results
    }

    // MARK: - Statistics

    func getTotalEntryCount() async -> Int {
        let sql = "SELECT COUNT(*) FROM text_entries"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }

        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int64(statement, 0))
        }

        return 0
    }

    deinit {
        sqlite3_close(db)
    }
}
