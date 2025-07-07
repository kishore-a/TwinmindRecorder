# TwinmindRecorder Architecture Document

## 1. Architectural Decisions

- **Modular Design:**
  - The app is organized into clear modules: Audio Recording, Transcription, Data Management, and UI. Each module is responsible for a single concern, improving maintainability and testability.
- **Swift Concurrency:**
  - Uses async/await and actor isolation for safe, responsive operations, especially for audio and data tasks.
- **SwiftData for Persistence:**
  - Chosen for its seamless integration with Swift and SwiftUI, and for its type-safe, modern approach to data modeling.
- **Testability:**
  - Core logic is separated from UI, and comprehensive unit/integration/performance tests are provided using the new Swift Testing framework.
- **Background Support:**
  - Audio recording and playback are designed to work in the background, with proper AVAudioSession configuration and Xcode background modes enabled.
- **Extensibility:**
  - The transcription service is abstracted, allowing easy switching between Apple's Speech framework (on-device) and remote engines (e.g., OpenAI Whisper).

## 2. Audio System Design

### Audio Route Changes
- **Detection:**
  - Listens for `AVAudioSession.routeChangeNotification` to detect changes (e.g., headphones unplugged, Bluetooth device connected).
- **Handling:**
  - On route change, the app checks the new output route:
    - If output is lost (e.g., headphones unplugged), recording is paused or stopped to prevent data loss.
    - If a new route is available, the session is reconfigured and recording/playback resumes if appropriate.
- **User Feedback:**
  - The UI is updated to reflect the current audio route and state, and users are notified if their action is required.

### Audio Interruptions
- **Detection:**
  - Listens for `AVAudioSession.interruptionNotification` (e.g., phone call, Siri, alarm).
- **Handling:**
  - On interruption begin, recording/playback is paused and state is saved.
  - On interruption end, the app checks if it should resume (using interruption options) and restores the previous state if possible.
- **Resilience:**
  - All audio state transitions are performed on the main actor to ensure thread safety and UI consistency.

## 3. Data Model Design

### SwiftData Schema
- **Entities:**
  - `RecordingSession`: Represents a user session, with properties for name, date, duration, and a relationship to segments.
  - `AudioSegment`: Represents a chunk of audio, with start time, duration, file URL, and a relationship to its transcription.
  - `Transcription`: Stores the text and status for a segment, and links back to its segment.
- **Relationships:**
  - One-to-many: `RecordingSession` → `AudioSegment`
  - One-to-one: `AudioSegment` → `Transcription`

### Performance Optimizations
- **Batch Operations:**
  - Uses batch inserts and fetches for large datasets to minimize UI and memory impact.
- **In-Memory Buffering:**
  - Audio data is buffered in memory during recording and only written to disk when necessary, reducing disk I/O.
- **FetchDescriptor:**
  - Uses `FetchDescriptor` for efficient, filtered queries (e.g., for search, grouping, and filtering in the session list).
- **Concurrency:**
  - All data operations are performed on the main actor or with proper isolation to avoid concurrency issues.
- **Testing:**
  - Performance tests simulate large datasets and measure query, insert, and disk operation times.

## 4. Known Issues & Areas for Improvement

- **Transcription Service:**
  - The app uses Apple's Speech framework for on-device transcription, which is reliable and private, but may have limitations in some languages or accents.
  - Remote transcription (OpenAI Whisper) may be subject to network latency and API limits.
- **Audio Edge Cases:**
  - Some rare audio route changes or interruptions may not be perfectly handled on all hardware/OS versions.
- **SwiftData Limitations:**
  - SwiftData is new and may have bugs or performance issues with very large datasets or complex relationships.
  - Migration strategies for schema changes are not yet implemented.
- **UI Responsiveness:**
  - With extremely large datasets, UI updates (especially grouping and search) may lag; further optimization or virtualization may be needed.
- **Testing on Real Devices:**
  - Some background and audio session behaviors can only be fully validated on real hardware, not simulators.
- **Error Handling:**
  - Some error cases (e.g., disk full, microphone hardware failure) are handled gracefully but could be surfaced to the user more clearly.

---

*This document should be updated as the architecture evolves and new features or improvements are made.* 