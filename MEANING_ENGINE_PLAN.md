# Meaning Engine Implementation Plan

## Overview
Transform LifeLog from passive screen capture + OCR into an active **Meaning Engine** that understands user behavior patterns, generates actionable hypotheses, and provides intelligent insights.

## Core Philosophy
**signal → features → hypotheses → evidence → actions**

---

## Phase 1: Foundation - New Data Models & Core Services

### 1.1 New Data Models

**InteractionEvent**
```swift
struct InteractionEvent {
    let id: Int64
    let timestamp: Date
    let type: InteractionType // .keystroke, .mouseClick, .mouseMove, .windowSwitch, .appSwitch
    let appName: String?
    let windowTitle: String?
    let intensity: Int // count of events in burst
    let metadata: [String: String]? // flexible data
}
```

**Session**
```swift
struct Session {
    let id: Int64
    let startTime: Date
    let endTime: Date?
    let primaryTopic: String? // inferred topic
    let appSequence: [String] // apps used in order
    let windowCount: Int
    let interactionCount: Int
    let outputArtifacts: Int // saves, commits, etc.
}
```

**Feature** (aggregated per 1-5 min window)
```swift
struct Feature {
    let id: Int64
    let windowStart: Date
    let windowEnd: Date
    let sessionId: Int64?

    // Time features
    let blockLength: TimeInterval
    let interruptionRate: Double
    let circadianBand: CircadianBand // .morning, .afternoon, .evening, .night

    // Context features
    let topicLabel: String?
    let topicContinuity: Double // 0-1
    let topicChurn: Double // switches per hour
    let repetitionScore: Double // 0-1

    // Behavior features
    let taskSwitchRate: Double // switches per hour
    let microDistractionCount: Int
    let flowIndicator: Double // 0-1
    let grindIndicator: Double // 0-1

    // Output features
    let outputDensity: Double // artifacts per hour

    // Media features
    let passiveConsumption: TimeInterval
    let activeConsumption: TimeInterval
}
```

**Hypothesis**
```swift
struct Hypothesis {
    let id: Int64
    let timestamp: Date
    let type: HypothesisType
    let confidence: Double // 0-1
    let evidence: [String] // list of supporting features
    let startTime: Date
    let endTime: Date?
    let metadata: [String: Any] // flexible data
}

enum HypothesisType {
    case deepWork
    case stuck
    case exploration
    case drift
    case scatter
    case complexityBuildup
    case looping
}
```

**Evidence**
```swift
struct Evidence {
    let id: Int64
    let hypothesisId: Int64
    let featureId: Int64
    let weight: Double // contribution to confidence
    let reason: String // human-readable explanation
}
```

**Artifact**
```swift
struct Artifact {
    let id: Int64
    let timestamp: Date
    let type: ArtifactType // .fileSave, .gitCommit, .export, .note, .completedTask
    let appName: String
    let path: String?
    let metadata: [String: String]?
}
```

### 1.2 Core Services

**InteractionTracker** (new)
- Monitor keyboard events via CGEventTap (accessibility permission required)
- Monitor mouse events
- Track app/window switches via NSWorkspace
- Aggregate into bursts/intensity metrics
- Store in lightweight queue for feature extraction

**FeatureExtractor** (new)
- Consume interaction events in 1-5 min windows
- Calculate time/context/behavior/output/media features
- Store features in database

**TopicAnalyzer** (new)
- Use lightweight embeddings for topic clustering
- Track topic continuity and churn
- Detect topic switches
- Store topic labels with sessions/features

**ArtifactDetector** (new)
- Monitor file system for saves (FSEvents)
- Monitor git commits (if in repo)
- Detect exports, completed tasks
- Store artifact events

**HypothesisGenerator** (new)
- Apply rule-based detection
- Calculate confidence scores
- Generate evidence chains
- Store hypotheses with supporting data

**MeaningEngine** (new - orchestrator)
- Coordinates all services
- Runs periodic analysis (hourly + daily)
- Generates insights and suggestions
- Manages data lifecycle

---

## Phase 2: Rule Implementation

### Deep Work Block Detection
```
IF:
  - Single topic OR topic continuity > 0.8
  - App switches ≤ 2
  - Duration ≥ 45 minutes
  - Flow indicator > 0.6
THEN:
  - Hypothesis: Deep Work Block
  - Confidence: based on flow + continuity
  - Evidence: topic label, app sequence, flow metrics
```

### Stuck Point Detection
```
IF:
  - Repetition score > 0.7
  - Topic continuity > 0.8 (same topic)
  - Output density < 0.3
  - Duration > 30 minutes
  - High edits/reverts (from interaction pattern)
THEN:
  - Hypothesis: Stuck/Impeded
  - Confidence: based on repetition + low output
  - Evidence: topic, output density, interaction patterns
  - Action: Create "Stuck Log" card, suggest experiment
```

### Exploration vs Drift
```
IF:
  - Passive consumption > 30 minutes
  - Topic similarity to current goal > 0.6
  - Active consumption indicators present (notes, interactions)
THEN:
  - Hypothesis: Exploration
ELSE IF:
  - Passive consumption > 30 minutes
  - Low topic similarity
  - No active indicators
THEN:
  - Hypothesis: Drift

Confidence: based on similarity score + active indicators
```

### Scatter/Fragmentation
```
IF:
  - Task switch rate ≥ 12 per hour
  - Average block length < 5 minutes
  - Topic churn > threshold
THEN:
  - Hypothesis: Scatter
  - Confidence: based on switch rate + block length
  - Action: Offer "Topic Lock" mode
```

### Complexity Build-up
```
IF:
  - Tool/app diversity ↑ (> N apps in topic)
  - Query/note frequency ↑
  - Decision points detected (repeated source checks)
THEN:
  - Hypothesis: Complexity Build-up
  - Confidence: based on diversity + query rate
  - Action: Mini-prioritizer (narrow scope, time-box)
```

### Looping Pattern
```
IF:
  - Frequent returns to same sources (≥ N times)
  - Low novelty (repetition score > threshold)
  - Duration > threshold
THEN:
  - Hypothesis: Looping
  - Confidence: based on repetition + return frequency
  - Action: Synthesize "So far" summary, suggest break-loop step
```

---

## Phase 3: Metrics System

### Core Metrics (calculated hourly/daily)

**Focus Ratio**
```
focus_ratio = deep_block_time / total_active_time
```

**Switches Per Hour**
```
switches_per_hour = (app_switches + window_switches + topic_switches) / active_hours
```

**Topic Entropy**
```
entropy = -Σ(p_i * log(p_i))  // Shannon entropy
where p_i = time_in_topic_i / total_time
Low entropy = focused, High entropy = fragmented
```

**Output Density**
```
output_density = artifact_count / active_hours
```

**Exploration:Production Ratio**
```
exp_prod_ratio = consumption_time / production_time
```

**Stuck Score**
```
stuck_score = (repetition_score * 0.4) +
              ((1 - output_density) * 0.3) +
              (duration_factor * 0.3)
```

---

## Phase 4: UI Components

### Daily Meaning Brief
- Summary card shown on app open
- Displays:
  - Deep blocks count + topics
  - Stuck points (if any)
  - Exploration vs Drift breakdown
  - Output density score
  - Top 3 topics with time spent
  - Top 3 suggestions based on hypotheses

### Weekly Map
- Heatmap view:
  - Focus ratio by day/hour
  - Fragmentation levels
  - Output density
- Topic transition graph (Sankey diagram)
- Stuck markers timeline
- Trend lines for core metrics

### Micro Nudges (gentle, contextual)
- After 20 min of scatter → "Enable Topic Lock?"
- When stuck detected → "Try one small experiment?"
- After 2 hours → "You've been in deep focus! Consider a break?"
- High drift → "This seems off-track. Refocus?"

### Auto Cards
- **Stuck Log**: Detailed view of stuck point with suggestions
- **Exploration Summary**: What you learned, key sources
- **Output Summary**: What you created today
- **Loop Warning**: Pattern detected, break-loop suggestions

### Metrics Dashboard
- Live metrics:
  - Today's focus ratio
  - Current switches/hour
  - Topic entropy (gauge)
  - Output density trend
  - Exploration:Production chart
- Historical trends (7/30/90 days)
- Comparison to baseline

### One-Tap Controls
- **Topic Lock**: Mute notifications, focus one window, 25-min timer
- **25-minute Focus**: Pomodoro-style deep work block
- **Summarize This**: Generate summary of current exploration
- **Narrow Scope**: Suggest scope reduction for complexity

---

## Phase 5: Storage Schema Extensions

### New Tables

**interaction_events**
```sql
CREATE TABLE interaction_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    type TEXT NOT NULL, -- 'keystroke', 'mouseClick', 'mouseMove', 'windowSwitch', 'appSwitch'
    app_name TEXT,
    window_title TEXT,
    intensity INTEGER DEFAULT 1,
    metadata TEXT, -- JSON
    FOREIGN KEY(session_id) REFERENCES sessions(id)
);
CREATE INDEX idx_interaction_events_timestamp ON interaction_events(timestamp);
CREATE INDEX idx_interaction_events_type ON interaction_events(type);
```

**sessions**
```sql
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    primary_topic TEXT,
    app_sequence TEXT, -- JSON array
    window_count INTEGER DEFAULT 0,
    interaction_count INTEGER DEFAULT 0,
    output_artifacts INTEGER DEFAULT 0
);
CREATE INDEX idx_sessions_time ON sessions(start_time, end_time);
```

**features**
```sql
CREATE TABLE features (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    window_start INTEGER NOT NULL,
    window_end INTEGER NOT NULL,
    session_id INTEGER,

    -- Time features
    block_length REAL,
    interruption_rate REAL,
    circadian_band TEXT,

    -- Context features
    topic_label TEXT,
    topic_continuity REAL,
    topic_churn REAL,
    repetition_score REAL,

    -- Behavior features
    task_switch_rate REAL,
    micro_distraction_count INTEGER,
    flow_indicator REAL,
    grind_indicator REAL,

    -- Output features
    output_density REAL,

    -- Media features
    passive_consumption REAL,
    active_consumption REAL,

    FOREIGN KEY(session_id) REFERENCES sessions(id)
);
CREATE INDEX idx_features_window ON features(window_start, window_end);
```

**hypotheses**
```sql
CREATE TABLE hypotheses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    type TEXT NOT NULL, -- 'deepWork', 'stuck', 'exploration', 'drift', etc.
    confidence REAL NOT NULL, -- 0-1
    evidence TEXT, -- JSON array of strings
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    metadata TEXT -- JSON
);
CREATE INDEX idx_hypotheses_time ON hypotheses(timestamp);
CREATE INDEX idx_hypotheses_type ON hypotheses(type);
```

**evidence**
```sql
CREATE TABLE evidence (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hypothesis_id INTEGER NOT NULL,
    feature_id INTEGER NOT NULL,
    weight REAL NOT NULL,
    reason TEXT NOT NULL,
    FOREIGN KEY(hypothesis_id) REFERENCES hypotheses(id) ON DELETE CASCADE,
    FOREIGN KEY(feature_id) REFERENCES features(id)
);
```

**artifacts**
```sql
CREATE TABLE artifacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    type TEXT NOT NULL, -- 'fileSave', 'gitCommit', 'export', 'note', 'completedTask'
    app_name TEXT NOT NULL,
    path TEXT,
    metadata TEXT -- JSON
);
CREATE INDEX idx_artifacts_timestamp ON artifacts(timestamp);
CREATE INDEX idx_artifacts_type ON artifacts(type);
```

**metrics** (daily aggregated)
```sql
CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL, -- YYYY-MM-DD
    focus_ratio REAL,
    switches_per_hour REAL,
    topic_entropy REAL,
    output_density REAL,
    exploration_production_ratio REAL,
    stuck_score REAL,
    deep_blocks_count INTEGER,
    total_active_time INTEGER
);
CREATE INDEX idx_metrics_date ON metrics(date);
```

---

## Phase 6: Implementation Order

### Sprint 1: Foundation (Week 1)
1. Create all new data models
2. Extend StorageService with new tables
3. Implement InteractionTracker (basic keyboard/mouse monitoring)
4. Test data collection pipeline

### Sprint 2: Feature Extraction (Week 1-2)
1. Implement FeatureExtractor service
2. Add windowing logic (1-5 min aggregation)
3. Calculate basic features (time, behavior)
4. Test feature generation

### Sprint 3: Hypothesis Generation (Week 2)
1. Implement HypothesisGenerator with rule engine
2. Add Deep Work Block detection
3. Add Stuck Point detection
4. Add Scatter detection
5. Test hypothesis generation with confidence scores

### Sprint 4: Topic Analysis (Week 2-3)
1. Implement TopicAnalyzer with lightweight embeddings
2. Add topic clustering logic
3. Calculate topic continuity/churn
4. Add Exploration vs Drift classification

### Sprint 5: MeaningEngine Integration (Week 3)
1. Create MeaningEngine orchestrator
2. Implement periodic analysis (hourly/daily)
3. Add metrics calculation
4. Test end-to-end pipeline

### Sprint 6: UI - Daily Brief (Week 3-4)
1. Design Daily Meaning Brief UI
2. Implement summary cards
3. Add suggestions display
4. Test with real data

### Sprint 7: UI - Weekly Map (Week 4)
1. Create heatmap visualizations
2. Implement topic transition graph
3. Add trend lines
4. Build metrics dashboard

### Sprint 8: Nudges & Cards (Week 4-5)
1. Implement micro-nudge system
2. Create auto-generated cards (Stuck Log, etc.)
3. Add one-tap control actions
4. Polish UI/UX

### Sprint 9: Artifact Detection (Week 5)
1. Implement ArtifactDetector service
2. Add file system monitoring
3. Add git commit detection
4. Calculate output density accurately

### Sprint 10: Polish & Optimization (Week 5-6)
1. Performance optimization
2. Battery/resource monitoring
3. Data retention policies
4. Privacy enhancements
5. User testing & iteration

---

## Technical Considerations

### Performance
- Lightweight event collection (< 1% CPU)
- Batch feature extraction (every 5 min)
- Async hypothesis generation
- Efficient database queries with proper indexes
- Resource monitoring (CPU/memory/battery)

### Privacy
- Local-first processing
- Minimal data retention (configurable)
- Encrypted at rest
- Hash-based deduplication
- User control over data

### Extensibility
- Plugin system for custom hypothesis rules
- Configurable thresholds
- User-defined topics/goals
- Custom artifact detectors

### User Experience
- Non-intrusive (passive collection)
- Actionable insights (not just data)
- Explainable (show evidence)
- Configurable (tune sensitivity)
- Opt-out options (disable tracking)

---

## Success Metrics

- User understands their focus patterns
- Actionable insights lead to behavior change
- Low cognitive overhead (< 5 min/day review)
- High signal-to-noise ratio (relevant insights)
- Positive user feedback on usefulness

---

## Next Steps

1. Review and approve plan
2. Start Sprint 1: Foundation
3. Iterative development with user feedback
4. Continuous refinement of rules and thresholds
