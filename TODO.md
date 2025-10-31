# LifeLog Development TODO

## Immediate Tasks (Before First Run)

- [ ] Create/verify Xcode project file includes all source files
- [ ] Test build in Xcode
- [ ] Fix any compilation errors
- [ ] Test screen recording permission flow
- [ ] Verify SQLite database creation
- [ ] Test basic OCR functionality

## Phase 1: Core Stability

### Critical Bugs
- [ ] Handle case where database initialization fails
- [ ] Add error recovery for OCR failures
- [ ] Implement proper crash reporting
- [ ] Add safeguards for disk space

### Performance
- [ ] Profile memory usage under continuous capture
- [ ] Optimize OCR for large screens/text
- [ ] Implement intelligent batching for DB writes
- [ ] Add performance metrics dashboard
- [ ] Test with 4K/5K displays

### Privacy & Security
- [ ] Implement secure storage for API keys (Keychain)
- [ ] Add encryption option for database
- [ ] Enhance sensitive content detection (SSN, credit cards, etc.)
- [ ] Add pause hotkey (global keyboard shortcut)
- [ ] Implement automatic pause on screensaver/lock

## Phase 2: Enhanced Intelligence

### AI Improvements
- [ ] Implement streaming responses from Gemini
- [ ] Add response caching to reduce API calls
- [ ] Implement automatic hourly/daily summaries
- [ ] Add activity classification (coding, browsing, writing, etc.)
- [ ] Context-aware suggestions

### Search Enhancements
- [ ] Fuzzy text search
- [ ] Search by time range UI
- [ ] Search by application
- [ ] Visual timeline of activity
- [ ] Export search results

### Apple Intelligence Integration
- [ ] Research Apple Intelligence APIs
- [ ] Implement local summarization
- [ ] On-device query processing for privacy
- [ ] Semantic search using embeddings

## Phase 3: User Experience

### UI/UX Improvements
- [ ] Add keyboard shortcuts (Cmd+Space to query, etc.)
- [ ] Implement dark mode support
- [ ] Add mini/compact mode for popover
- [ ] Animated transitions
- [ ] Better loading states
- [ ] Toast notifications for important events

### Settings & Configuration
- [ ] Advanced OCR settings (language, accuracy level)
- [ ] Customizable capture hotkeys
- [ ] Schedule-based capture (work hours only)
- [ ] Per-app capture rules
- [ ] Data retention policies

### Onboarding
- [ ] First-run tutorial
- [ ] Sample queries/suggestions
- [ ] Permission setup wizard
- [ ] API key setup helper

## Phase 4: Advanced Features

### Data Management
- [ ] Export to JSON/CSV
- [ ] Import from other sources
- [ ] Data compression/archival
- [ ] Cloud backup option (encrypted)
- [ ] Multi-Mac sync (iCloud)

### Analytics & Insights
- [ ] Time tracking by app/activity
- [ ] Daily/weekly reports
- [ ] Productivity metrics
- [ ] Focus time analysis
- [ ] Distraction detection

### Automation
- [ ] Zapier/IFTTT integration
- [ ] Custom workflows
- [ ] Auto-tagging based on content
- [ ] Smart reminders based on context
- [ ] API for third-party integrations

### Multi-Display Support
- [ ] Capture all displays
- [ ] Per-display configuration
- [ ] Display selection UI

## Technical Debt

### Code Quality
- [ ] Add unit tests for core services
- [ ] Add integration tests
- [ ] Improve error handling throughout
- [ ] Add logging levels (debug, info, error)
- [ ] Document all public APIs

### Architecture
- [ ] Refactor storage layer to use Swift Concurrency properly
- [ ] Improve dependency injection
- [ ] Add protocol abstractions for services
- [ ] Consider MVVM vs current architecture

### Dependencies
- [ ] Evaluate switching to local LLM (Llama, etc.)
- [ ] Consider alternative OCR libraries
- [ ] Evaluate SQLite alternatives (Realm, CoreData)

## Known Issues

### High Priority
- [ ] App may crash on permission denial
- [ ] Memory leak in OCR service (verify)
- [ ] Database locking under high load
- [ ] Gemini API rate limiting not handled

### Medium Priority
- [ ] Menu bar icon doesn't update immediately
- [ ] Settings window doesn't save all changes
- [ ] Query view doesn't scroll to new responses
- [ ] Performance monitor shows stale data

### Low Priority
- [ ] UI glitches on macOS 14.0 vs 14.1
- [ ] Some SF Symbols not available on older macOS
- [ ] Dark mode colors not perfect

## Future Ideas (Backlog)

- [ ] Browser extension for context
- [ ] Mobile companion app (iOS)
- [ ] Shared team lifelogs (enterprise)
- [ ] Plugin system for custom processors
- [ ] Machine learning for personal patterns
- [ ] Voice memo integration
- [ ] Email/calendar integration
- [ ] Git commit correlation
- [ ] Slack/Discord integration
- [ ] Screenshot OCR from clipboard
- [ ] PDF document indexing
- [ ] Video meeting transcription
- [ ] Smart context switching detection

## Documentation

- [ ] API documentation (if opening for plugins)
- [ ] Architecture decision records (ADRs)
- [ ] Performance benchmarks
- [ ] Privacy policy (if distributing)
- [ ] Video tutorials
- [ ] FAQ expansion

## Distribution

- [ ] App Store preparation
- [ ] Code signing for distribution
- [ ] Notarization
- [ ] Update mechanism
- [ ] Analytics (privacy-respecting)
- [ ] Crash reporting (opt-in)

## Community

- [ ] GitHub repository (if open-sourcing)
- [ ] Contributing guidelines
- [ ] Issue templates
- [ ] PR templates
- [ ] Code of conduct

---

**Priority Legend:**
- **Critical**: Blocks basic functionality
- **High**: Important for good user experience
- **Medium**: Nice to have, improves quality
- **Low**: Polish, edge cases

**Status:**
- [ ] Not started
- [~] In progress
- [x] Completed
- [-] Blocked
- [?] Needs investigation
