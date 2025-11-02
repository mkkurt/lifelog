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

        -- Meaning Engine Tables

        -- Interaction events table
        CREATE TABLE IF NOT EXISTS interaction_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            type TEXT NOT NULL,
            app_name TEXT,
            window_title TEXT,
            intensity INTEGER DEFAULT 1,
            session_id INTEGER,
            metadata TEXT,
            FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE SET NULL
        );

        CREATE INDEX IF NOT EXISTS idx_interaction_events_timestamp ON interaction_events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_interaction_events_type ON interaction_events(type);
        CREATE INDEX IF NOT EXISTS idx_interaction_events_session ON interaction_events(session_id);

        -- Sessions table
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            primary_topic TEXT,
            app_sequence TEXT,
            window_count INTEGER DEFAULT 0,
            interaction_count INTEGER DEFAULT 0,
            output_artifacts INTEGER DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_sessions_time ON sessions(start_time, end_time);
        CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions(end_time) WHERE end_time IS NULL;

        -- Features table
        CREATE TABLE IF NOT EXISTS features (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            window_start INTEGER NOT NULL,
            window_end INTEGER NOT NULL,
            session_id INTEGER,
            block_length REAL DEFAULT 0,
            interruption_rate REAL DEFAULT 0,
            circadian_band TEXT,
            topic_label TEXT,
            topic_continuity REAL DEFAULT 0,
            topic_churn REAL DEFAULT 0,
            repetition_score REAL DEFAULT 0,
            task_switch_rate REAL DEFAULT 0,
            micro_distraction_count INTEGER DEFAULT 0,
            flow_indicator REAL DEFAULT 0,
            grind_indicator REAL DEFAULT 0,
            output_density REAL DEFAULT 0,
            passive_consumption REAL DEFAULT 0,
            active_consumption REAL DEFAULT 0,
            FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE SET NULL
        );

        CREATE INDEX IF NOT EXISTS idx_features_window ON features(window_start, window_end);
        CREATE INDEX IF NOT EXISTS idx_features_session ON features(session_id);

        -- Hypotheses table
        CREATE TABLE IF NOT EXISTS hypotheses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            type TEXT NOT NULL,
            confidence REAL NOT NULL,
            evidence TEXT,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            metadata TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_hypotheses_timestamp ON hypotheses(timestamp);
        CREATE INDEX IF NOT EXISTS idx_hypotheses_type ON hypotheses(type);
        CREATE INDEX IF NOT EXISTS idx_hypotheses_active ON hypotheses(end_time) WHERE end_time IS NULL;

        -- Evidence table
        CREATE TABLE IF NOT EXISTS evidence (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hypothesis_id INTEGER NOT NULL,
            feature_id INTEGER NOT NULL,
            weight REAL NOT NULL,
            reason TEXT NOT NULL,
            FOREIGN KEY(hypothesis_id) REFERENCES hypotheses(id) ON DELETE CASCADE,
            FOREIGN KEY(feature_id) REFERENCES features(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_evidence_hypothesis ON evidence(hypothesis_id);
        CREATE INDEX IF NOT EXISTS idx_evidence_feature ON evidence(feature_id);

        -- Artifacts table
        CREATE TABLE IF NOT EXISTS artifacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            type TEXT NOT NULL,
            app_name TEXT NOT NULL,
            path TEXT,
            metadata TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_artifacts_timestamp ON artifacts(timestamp);
        CREATE INDEX IF NOT EXISTS idx_artifacts_type ON artifacts(type);

        -- Daily metrics table
        CREATE TABLE IF NOT EXISTS daily_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL UNIQUE,
            focus_ratio REAL DEFAULT 0,
            switches_per_hour REAL DEFAULT 0,
            topic_entropy REAL DEFAULT 0,
            output_density REAL DEFAULT 0,
            exploration_production_ratio REAL DEFAULT 0,
            stuck_score REAL DEFAULT 0,
            deep_blocks_count INTEGER DEFAULT 0,
            total_active_time REAL DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_daily_metrics_date ON daily_metrics(date);
        """

        // Execute entire schema at once since SQLite can handle multiple statements
        // and this preserves trigger definitions with internal semicolons
        if sqlite3_exec(db, schema, nil, nil, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            Logger.error("SQL error during schema initialization: \(error)", log: Logger.storage)
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

    // MARK: - Sessions

    func saveSession(_ session: Session) async -> Int64 {
        let sql = """
        INSERT INTO sessions (start_time, end_time, primary_topic, app_sequence, window_count, interaction_count, output_artifacts)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare session insert", log: Logger.storage)
            return 0
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(session.startTime.timeIntervalSince1970))
        if let endTime = session.endTime {
            sqlite3_bind_int64(statement, 2, Int64(endTime.timeIntervalSince1970))
        } else {
            sqlite3_bind_null(statement, 2)
        }
        sqlite3_bind_text(statement, 3, (session.primaryTopic as NSString?)?.utf8String, -1, nil)
        if let appSeqJSON = try? JSONEncoder().encode(session.appSequence),
           let appSeqString = String(data: appSeqJSON, encoding: .utf8) {
            sqlite3_bind_text(statement, 4, (appSeqString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_int(statement, 5, Int32(session.windowCount))
        sqlite3_bind_int(statement, 6, Int32(session.interactionCount))
        sqlite3_bind_int(statement, 7, Int32(session.outputArtifacts))

        if sqlite3_step(statement) == SQLITE_DONE {
            return sqlite3_last_insert_rowid(db)
        } else {
            Logger.error("Failed to save session", log: Logger.storage)
            return 0
        }
    }

    func getActiveSession() async -> Session? {
        let sql = "SELECT id, start_time, primary_topic, app_sequence, window_count, interaction_count, output_artifacts FROM sessions WHERE end_time IS NULL ORDER BY start_time DESC LIMIT 1"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            let appSeqString = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            let appSeq: [String]
            if let appSeqString = appSeqString,
               let data = appSeqString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                appSeq = decoded
            } else {
                appSeq = []
            }

            return Session(
                id: sqlite3_column_int64(statement, 0),
                startTime: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1))),
                endTime: nil,
                primaryTopic: sqlite3_column_text(statement, 2).map { String(cString: $0) },
                appSequence: appSeq,
                windowCount: Int(sqlite3_column_int(statement, 4)),
                interactionCount: Int(sqlite3_column_int(statement, 5)),
                outputArtifacts: Int(sqlite3_column_int(statement, 6))
            )
        }
        return nil
    }

    func endSession(_ sessionId: Int64, endTime: Date) async {
        let sql = "UPDATE sessions SET end_time = ? WHERE id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(endTime.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, sessionId)
        sqlite3_step(statement)
    }

    // MARK: - Interaction Events

    func getInteractionEvents(from startTime: Date, to endTime: Date) async -> [InteractionEvent] {
        let sql = """
        SELECT id, timestamp, type, app_name, window_title, intensity, session_id, metadata
        FROM interaction_events
        WHERE timestamp BETWEEN ? AND ?
        ORDER BY timestamp ASC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare interaction events query", log: Logger.storage)
            return []
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(startTime.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, Int64(endTime.timeIntervalSince1970))

        var events: [InteractionEvent] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let typeString = String(cString: sqlite3_column_text(statement, 2))
            guard let type = InteractionType(rawValue: typeString) else { continue }

            let sessionId: Int64? = {
                let value = sqlite3_column_int64(statement, 6)
                return value == 0 ? nil : value
            }()

            let metadataString = sqlite3_column_text(statement, 7).map { String(cString: $0) }
            let metadata: [String: String]? = {
                guard let metadataString = metadataString,
                      let data = metadataString.data(using: .utf8),
                      let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                    return nil
                }
                return decoded
            }()

            let event = InteractionEvent(
                id: sqlite3_column_int64(statement, 0),
                timestamp: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1))),
                type: type,
                appName: sqlite3_column_text(statement, 3).map { String(cString: $0) },
                windowTitle: sqlite3_column_text(statement, 4).map { String(cString: $0) },
                intensity: Int(sqlite3_column_int(statement, 5)),
                sessionId: sessionId,
                metadata: metadata
            )
            events.append(event)
        }

        return events
    }

    func saveInteractionEvent(_ event: InteractionEvent) async -> Int64 {
        let sql = """
        INSERT INTO interaction_events (timestamp, type, app_name, window_title, intensity, session_id, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare interaction event insert", log: Logger.storage)
            return 0
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(event.timestamp.timeIntervalSince1970))
        sqlite3_bind_text(statement, 2, (event.type.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (event.appName as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (event.windowTitle as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_int(statement, 5, Int32(event.intensity))
        if let sessionId = event.sessionId {
            sqlite3_bind_int64(statement, 6, sessionId)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        if let metadata = event.metadata,
           let metadataJSON = try? JSONEncoder().encode(metadata),
           let metadataString = String(data: metadataJSON, encoding: .utf8) {
            sqlite3_bind_text(statement, 7, (metadataString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if sqlite3_step(statement) == SQLITE_DONE {
            return sqlite3_last_insert_rowid(db)
        } else {
            Logger.error("Failed to save interaction event", log: Logger.storage)
            return 0
        }
    }

    // MARK: - Features

    func getFeatures(from startTime: Date, to endTime: Date) async -> [Feature] {
        let sql = """
        SELECT id, window_start, window_end, session_id, block_length, interruption_rate, circadian_band,
               topic_label, topic_continuity, topic_churn, repetition_score, task_switch_rate,
               micro_distraction_count, flow_indicator, grind_indicator, output_density,
               passive_consumption, active_consumption
        FROM features
        WHERE window_start >= ? AND window_end <= ?
        ORDER BY window_start ASC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare features query", log: Logger.storage)
            return []
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(startTime.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, Int64(endTime.timeIntervalSince1970))

        var features: [Feature] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let circadianString = String(cString: sqlite3_column_text(statement, 6))
            let circadianBand = CircadianBand(rawValue: circadianString) ?? .unknown

            let sessionId: Int64? = {
                let value = sqlite3_column_int64(statement, 3)
                return value == 0 ? nil : value
            }()

            let feature = Feature(
                id: sqlite3_column_int64(statement, 0),
                windowStart: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1))),
                windowEnd: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2))),
                sessionId: sessionId,
                blockLength: sqlite3_column_double(statement, 4),
                interruptionRate: sqlite3_column_double(statement, 5),
                circadianBand: circadianBand,
                topicLabel: sqlite3_column_text(statement, 7).map { String(cString: $0) },
                topicContinuity: sqlite3_column_double(statement, 8),
                topicChurn: sqlite3_column_double(statement, 9),
                repetitionScore: sqlite3_column_double(statement, 10),
                taskSwitchRate: sqlite3_column_double(statement, 11),
                microDistractionCount: Int(sqlite3_column_int(statement, 12)),
                flowIndicator: sqlite3_column_double(statement, 13),
                grindIndicator: sqlite3_column_double(statement, 14),
                outputDensity: sqlite3_column_double(statement, 15),
                passiveConsumption: sqlite3_column_double(statement, 16),
                activeConsumption: sqlite3_column_double(statement, 17)
            )
            features.append(feature)
        }

        return features
    }

    func saveFeature(_ feature: Feature) async -> Int64 {
        let sql = """
        INSERT INTO features (window_start, window_end, session_id, block_length, interruption_rate, circadian_band,
                              topic_label, topic_continuity, topic_churn, repetition_score, task_switch_rate,
                              micro_distraction_count, flow_indicator, grind_indicator, output_density,
                              passive_consumption, active_consumption)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare feature insert", log: Logger.storage)
            return 0
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(feature.windowStart.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, Int64(feature.windowEnd.timeIntervalSince1970))
        if let sessionId = feature.sessionId {
            sqlite3_bind_int64(statement, 3, sessionId)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_double(statement, 4, feature.blockLength)
        sqlite3_bind_double(statement, 5, feature.interruptionRate)
        sqlite3_bind_text(statement, 6, (feature.circadianBand.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 7, (feature.topicLabel as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_double(statement, 8, feature.topicContinuity)
        sqlite3_bind_double(statement, 9, feature.topicChurn)
        sqlite3_bind_double(statement, 10, feature.repetitionScore)
        sqlite3_bind_double(statement, 11, feature.taskSwitchRate)
        sqlite3_bind_int(statement, 12, Int32(feature.microDistractionCount))
        sqlite3_bind_double(statement, 13, feature.flowIndicator)
        sqlite3_bind_double(statement, 14, feature.grindIndicator)
        sqlite3_bind_double(statement, 15, feature.outputDensity)
        sqlite3_bind_double(statement, 16, feature.passiveConsumption)
        sqlite3_bind_double(statement, 17, feature.activeConsumption)

        if sqlite3_step(statement) == SQLITE_DONE {
            return sqlite3_last_insert_rowid(db)
        } else {
            Logger.error("Failed to save feature", log: Logger.storage)
            return 0
        }
    }

    // MARK: - Hypotheses

    func saveHypothesis(_ hypothesis: Hypothesis) async -> Int64 {
        let sql = """
        INSERT INTO hypotheses (timestamp, type, confidence, evidence, start_time, end_time, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare hypothesis insert", log: Logger.storage)
            return 0
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(hypothesis.timestamp.timeIntervalSince1970))
        sqlite3_bind_text(statement, 2, (hypothesis.type.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 3, hypothesis.confidence)
        if let evidenceJSON = try? JSONEncoder().encode(hypothesis.evidence),
           let evidenceString = String(data: evidenceJSON, encoding: .utf8) {
            sqlite3_bind_text(statement, 4, (evidenceString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_int64(statement, 5, Int64(hypothesis.startTime.timeIntervalSince1970))
        if let endTime = hypothesis.endTime {
            sqlite3_bind_int64(statement, 6, Int64(endTime.timeIntervalSince1970))
        } else {
            sqlite3_bind_null(statement, 6)
        }
        if let metadata = hypothesis.metadata,
           let metadataJSON = try? JSONEncoder().encode(metadata),
           let metadataString = String(data: metadataJSON, encoding: .utf8) {
            sqlite3_bind_text(statement, 7, (metadataString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if sqlite3_step(statement) == SQLITE_DONE {
            return sqlite3_last_insert_rowid(db)
        } else {
            Logger.error("Failed to save hypothesis", log: Logger.storage)
            return 0
        }
    }

    func endHypothesis(_ hypothesisId: Int64, endTime: Date) async {
        let sql = "UPDATE hypotheses SET end_time = ? WHERE id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(endTime.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, hypothesisId)
        sqlite3_step(statement)
    }

    // MARK: - Evidence

    func saveEvidence(_ evidence: Evidence) async -> Int64 {
        let sql = """
        INSERT INTO evidence (hypothesis_id, feature_id, weight, reason)
        VALUES (?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare evidence insert", log: Logger.storage)
            return 0
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, evidence.hypothesisId)
        sqlite3_bind_int64(statement, 2, evidence.featureId)
        sqlite3_bind_double(statement, 3, evidence.weight)
        sqlite3_bind_text(statement, 4, (evidence.reason as NSString).utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_DONE {
            return sqlite3_last_insert_rowid(db)
        } else {
            Logger.error("Failed to save evidence", log: Logger.storage)
            return 0
        }
    }

    // MARK: - Artifacts

    func saveArtifact(_ artifact: Artifact) async -> Int64 {
        let sql = """
        INSERT INTO artifacts (timestamp, type, app_name, path, metadata)
        VALUES (?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare artifact insert", log: Logger.storage)
            return 0
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(artifact.timestamp.timeIntervalSince1970))
        sqlite3_bind_text(statement, 2, (artifact.type.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (artifact.appName as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (artifact.path as NSString?)?.utf8String, -1, nil)
        if let metadata = artifact.metadata,
           let metadataJSON = try? JSONEncoder().encode(metadata),
           let metadataString = String(data: metadataJSON, encoding: .utf8) {
            sqlite3_bind_text(statement, 5, (metadataString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if sqlite3_step(statement) == SQLITE_DONE {
            return sqlite3_last_insert_rowid(db)
        } else {
            Logger.error("Failed to save artifact", log: Logger.storage)
            return 0
        }
    }

    // MARK: - Daily Metrics

    func saveDailyMetrics(_ metrics: DailyMetrics) async -> Int64 {
        let sql = """
        INSERT OR REPLACE INTO daily_metrics (date, focus_ratio, switches_per_hour, topic_entropy,
                                               output_density, exploration_production_ratio, stuck_score,
                                               deep_blocks_count, total_active_time)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            Logger.error("Failed to prepare daily metrics insert", log: Logger.storage)
            return 0
        }

        defer { sqlite3_finalize(statement) }

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: metrics.date)
        let dateOnly = calendar.date(from: dateComponents) ?? metrics.date

        sqlite3_bind_int64(statement, 1, Int64(dateOnly.timeIntervalSince1970))
        sqlite3_bind_double(statement, 2, metrics.focusRatio)
        sqlite3_bind_double(statement, 3, metrics.switchesPerHour)
        sqlite3_bind_double(statement, 4, metrics.topicEntropy)
        sqlite3_bind_double(statement, 5, metrics.outputDensity)
        sqlite3_bind_double(statement, 6, metrics.explorationProductionRatio)
        sqlite3_bind_double(statement, 7, metrics.stuckScore)
        sqlite3_bind_int(statement, 8, Int32(metrics.deepBlocksCount))
        sqlite3_bind_double(statement, 9, metrics.totalActiveTime)

        if sqlite3_step(statement) == SQLITE_DONE {
            return sqlite3_last_insert_rowid(db)
        } else {
            Logger.error("Failed to save daily metrics", log: Logger.storage)
            return 0
        }
    }

    func getDailyMetrics(for date: Date) async -> DailyMetrics? {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let dateOnly = calendar.date(from: dateComponents) ?? date

        let sql = """
        SELECT id, date, focus_ratio, switches_per_hour, topic_entropy, output_density,
               exploration_production_ratio, stuck_score, deep_blocks_count, total_active_time
        FROM daily_metrics WHERE date = ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(dateOnly.timeIntervalSince1970))

        if sqlite3_step(statement) == SQLITE_ROW {
            return DailyMetrics(
                id: sqlite3_column_int64(statement, 0),
                date: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1))),
                focusRatio: sqlite3_column_double(statement, 2),
                switchesPerHour: sqlite3_column_double(statement, 3),
                topicEntropy: sqlite3_column_double(statement, 4),
                outputDensity: sqlite3_column_double(statement, 5),
                explorationProductionRatio: sqlite3_column_double(statement, 6),
                stuckScore: sqlite3_column_double(statement, 7),
                deepBlocksCount: Int(sqlite3_column_int(statement, 8)),
                totalActiveTime: sqlite3_column_double(statement, 9)
            )
        }
        return nil
    }

    deinit {
        sqlite3_close(db)
    }
}
