# LifeLog Architecture

## Vision
A personal memory augmentation system that captures, indexes, and makes searchable everything you see and do on your Mac.

## Core Problem
"I can't remember what was on my mind, what I was going to do, what email I was going to write, what I was tinkering with."

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Menu Bar UI                             │
│  (Status, Controls, Query Interface, Settings)               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Application Core                           │
│  (State Management, Coordination, Privacy Controls)          │
└─────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Screen     │ │     OCR      │ │      AI      │ │   Storage    │
│   Capture    │ │   Service    │ │   Service    │ │    Layer     │
│   Service    │ │              │ │              │ │              │
│              │ │              │ │              │ │              │
│ ScreenCapt.  │ │   Vision     │ │  Gemini API  │ │   SQLite     │
│ Kit API      │ │  Framework   │ │   +Local     │ │   + FTS5     │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

## Components

### 1. Screen Capture Service
**Technology**: ScreenCaptureKit (macOS 12.3+)
**Strategy**: Intelligent interval-based capture
- Capture screenshots every 5-10 seconds (configurable)
- Smart change detection: skip identical frames
- Multi-display support
- Window-level capture for better privacy control
- Low CPU overhead (<5% target)

**Privacy Features**:
- Exclude specific apps (password managers, etc.)
- Pause on incognito/private browsing
- User-controlled blacklist

### 2. OCR Service
**Technology**: Vision Framework (VNRecognizeTextRequest)
**Strategy**: Async processing pipeline
- Queue-based processing to avoid blocking
- Differential OCR: only process changed regions
- Confidence thresholding (ignore low-confidence text)
- Language detection and multi-language support
- Batch processing for efficiency

**Optimizations**:
- Downscale images before OCR if needed
- Region-of-interest detection
- Skip OCR on static content

### 3. Storage Layer
**Technology**: SQLite + FTS5
**Schema**:
```sql
-- Raw captures
CREATE TABLE captures (
    id INTEGER PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    screen_hash TEXT,
    image_path TEXT,  -- optional, for debugging
    UNIQUE(screen_hash)
);

-- Recognized text
CREATE TABLE text_entries (
    id INTEGER PRIMARY KEY,
    capture_id INTEGER,
    timestamp INTEGER NOT NULL,
    raw_text TEXT NOT NULL,
    confidence REAL,
    app_name TEXT,
    window_title TEXT,
    screen_region TEXT,  -- JSON: {x, y, width, height}
    FOREIGN KEY(capture_id) REFERENCES captures(id)
);

-- Full-text search index
CREATE VIRTUAL TABLE text_entries_fts USING fts5(
    raw_text,
    content=text_entries,
    content_rowid=id
);

-- AI summaries
CREATE TABLE summaries (
    id INTEGER PRIMARY KEY,
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL,
    summary TEXT NOT NULL,
    keywords TEXT,  -- JSON array
    activity_type TEXT
);

-- User queries and responses
CREATE TABLE query_log (
    id INTEGER PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    query TEXT NOT NULL,
    response TEXT NOT NULL,
    context_used TEXT  -- IDs of relevant entries
);
```

**Indexes**:
- Timestamp-based indexes for chronological queries
- App name index for filtering
- Hash index for deduplication

### 4. AI Service
**Technology**: Gemini AI (primary) + Apple Intelligence (future)

**Use Cases**:
1. **Periodic Summarization**
   - Hourly summaries: "Working on LifeLog project architecture"
   - Daily summaries: "Focused on project planning and documentation"

2. **Natural Language Queries**
   - "What was I working on Tuesday afternoon?"
   - "Find that email address I saw yesterday"
   - "What was that command I ran this morning?"

3. **Proactive Insights**
   - "You've been on this task for 3 hours"
   - "You mentioned checking email 4 times today"
   - Context restoration: "You were editing Architecture.md"

**API Integration**:
- Gemini API with retry logic and rate limiting
- Context window management (chunk long logs)
- Streaming responses for better UX
- Local fallback for privacy-sensitive queries

### 5. Performance Optimization

**Memory Management**:
- Circular buffer for recent captures
- Lazy loading of historical data
- Image cleanup (delete after OCR)
- Compression for archived data

**CPU Optimization**:
- Background QoS for non-critical tasks
- Adaptive capture rate (slow down when idle)
- Batch processing during idle time
- Metal/GPU acceleration for OCR if beneficial

**Storage Optimization**:
- Deduplication of identical screens
- Text compression (ZSTD)
- Pruning strategy (keep summaries, archive raw data)
- Configurable retention period

### 6. Privacy & Security

**Permissions**:
- Screen Recording permission (required)
- Accessibility permission (for window metadata)
- Network permission (for AI API)

**Data Protection**:
- All data stored locally
- Optional encryption at rest
- No telemetry or analytics
- Clear data deletion workflow

**Sensitive Content Filtering**:
- Password field detection
- Credit card number redaction
- Configurable app exclusions
- Private browsing detection

## Development Phases

### Phase 1: Core Foundation (Current)
- [x] Basic screen capture
- [ ] OCR integration
- [ ] SQLite storage
- [ ] Basic menu bar UI

### Phase 2: Intelligence
- [ ] Gemini AI integration
- [ ] Summarization pipeline
- [ ] Natural language queries
- [ ] Context restoration

### Phase 3: Polish
- [ ] Performance optimization
- [ ] Advanced privacy controls
- [ ] Settings UI
- [ ] Export/import features

### Phase 4: Advanced Features
- [ ] Apple Intelligence integration
- [ ] Proactive suggestions
- [ ] Cross-device sync (optional)
- [ ] Workflow automation

## Technical Decisions

### Why ScreenCaptureKit?
- Modern, efficient API
- Lower overhead than legacy APIs
- Better privacy controls
- Window-level granularity

### Why SQLite + FTS5?
- Embedded, no server needed
- FTS5 provides excellent full-text search
- Proven reliability
- Easy backup/export

### Why Gemini AI?
- Strong summarization capabilities
- Good context window
- Affordable pricing
- Fallback to local possible

## Future Considerations
- Offline-first AI with local LLMs
- Timeline visualization
- Collaboration features (share contexts)
- Plugin system for custom processors
