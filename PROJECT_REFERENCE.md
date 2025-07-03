# TwinmindRecorder - Project Reference Guide

This document serves as your comprehensive knowledge base for the TwinmindRecorder iOS app. It contains detailed information about the current implementation, architecture decisions, and technical details.

## Project Overview

**Current Status**: Core audio recording, segmentation, and transcription integration complete
**Target Platform**: iOS 17.0+
**Architecture**: SwiftUI + SwiftData + AVAudioEngine
**API Integration**: OpenAI Whisper for transcription

## File Structure & Purpose

### Core Files
```
TwinmindRecorder/
├── TwinmindRecorderApp.swift          # App entry point
├── ContentView.swift                  # Main UI (basic implementation)
├── AudioRecorderManager.swift         # Audio recording & segmentation logic
├── TranscriptionService.swift         # API integration & transcription
├── RecordingSession.swift             # SwiftData model for sessions
├── AudioSegment.swift                 # SwiftData model for segments
├── Transcription.swift                # SwiftData model for transcriptions
├── Info.plist                         # App configuration & API keys
└── Assets.xcassets/                   # App icons & colors
```

## Data Models Architecture

### RecordingSession
- **Purpose**: Represents a complete recording session
- **Key Properties**:
  - `id`: Unique identifier (UUID)
  - `date`: When the session started
  - `duration`: Total recording duration
  - `segments`: Relationship to AudioSegment objects
- **Relationships**: One-to-many with AudioSegment (cascade delete)

### AudioSegment
- **Purpose**: Individual 30-second audio chunks
- **Key Properties**:
  - `id`: Unique identifier (UUID)
  - `startTime`: Unix timestamp when segment started
  - `duration`: Segment duration in seconds
  - `fileURL`: Path to the audio file
  - `session`: Relationship to parent RecordingSession
  - `transcription`: Relationship to Transcription object
- **Relationships**: Many-to-one with RecordingSession, One-to-one with Transcription

### Transcription
- **Purpose**: Stores transcription results and status
- **Key Properties**:
  - `id`: Unique identifier (UUID)
  - `text`: Transcribed text content
  - `status`: Enum (pending, processing, completed, failed)
  - `error`: Error message if transcription failed
  - `segment`: Relationship to parent AudioSegment
- **Relationships**: One-to-one with AudioSegment

## Audio System Implementation

### AudioRecorderManager
**Current Implementation**:
- Uses AVAudioEngine for high-quality recording
- Real-time segmentation every 30 seconds
- Handles audio interruptions and route changes
- Integrates with SwiftData for persistence

**Key Methods**:
- `startRecording()`: Initiates recording with permission check
- `beginRecordingSegment()`: Creates new audio file and starts recording
- `rotateSegment()`: Closes current file, saves segment, starts new one
- `stopRecording()`: Finalizes recording and saves last segment

**Audio Session Configuration**:
```swift
Category: .playAndRecord
Mode: .default
Options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay]
```

**File Management**:
- Files stored in temporary directory
- Naming convention: `segment_{timestamp}_{index}.m4a`
- Format: M4A (configurable)
- Buffer size: 1024 samples

### Interruption Handling
**Implemented Features**:
- Phone calls: Automatically pause/resume
- Route changes: Handle headphone plug/unplug
- Backgrounding: Basic support (needs entitlements)
- Permission changes: Graceful handling

## Transcription System

### TranscriptionService
**Current Implementation**:
- Singleton pattern for easy access
- OpenAI Whisper API integration
- Multipart/form-data request format
- Basic error handling and status tracking

**API Integration Details**:
- **Endpoint**: `https://api.openai.com/v1/audio/transcriptions`
- **Authentication**: Bearer token from Info.plist
- **Request Format**: Multipart/form-data with model and file
- **Response**: JSON with "text" field

**Current Limitations**:
- No retry logic implemented
- No offline queue processing
- No local fallback transcription
- Basic error handling only

### Transcription Flow
1. Segment created → AudioSegment saved to SwiftData
2. TranscriptionService.transcribe() called
3. Transcription object created with .processing status
4. Audio file sent to OpenAI API
5. Response parsed and Transcription updated
6. SwiftData context saved

## UI Implementation

### Current State
**ContentView.swift**:
- Basic recording controls (start/stop buttons)
- Real-time recording status display
- Placeholder for session list
- Uses @StateObject for AudioRecorderManager

**Missing UI Components**:
- Session list with SwiftData @Query
- Segment detail view
- Transcription status indicators
- Error message display
- Search and filter functionality

## Security & Configuration

### API Key Management
**Current Implementation**:
- API key stored in Info.plist
- Info.plist added to .gitignore
- Key accessed via Bundle.main.object(forInfoDictionaryKey:)

**Security Considerations**:
- Keys not committed to repository
- Consider Keychain for production
- No encryption of audio files (planned)

### Permissions
**Required Permissions**:
- Microphone access (NSMicrophoneUsageDescription)
- Background audio (if implementing background recording)

## Performance Considerations

### Current Optimizations
- Real-time audio processing with AVAudioEngine
- Direct file writing to disk
- SwiftData lazy loading
- Efficient memory management

### Known Bottlenecks
- Single-threaded transcription processing
- No concurrent API requests
- Limited offline queue management
- No file cleanup strategy

## Error Handling

### Current Implementation
**Audio Errors**:
- Permission denials handled gracefully
- File write errors trigger recording stop
- Session interruption recovery

**API Errors**:
- Network failures marked as failed
- Basic error message storage
- No automatic retry logic

**Missing Error Handling**:
- Storage space exhaustion
- API rate limiting
- Data corruption scenarios
- Background processing failures

## Testing Status

### Current Coverage
- Manual testing of recording functionality
- Basic API integration testing
- SwiftData relationship validation

### Missing Tests
- Unit tests for business logic
- Integration tests for audio system
- API error scenario testing
- Performance testing with large datasets
- UI automation tests

## Next Development Priorities

### High Priority
1. **UI Enhancement**: Implement session list and detail views
2. **Error Handling**: Add comprehensive error recovery
3. **Retry Logic**: Implement transcription retry with exponential backoff
4. **Offline Queue**: Process queued transcriptions when network available

### Medium Priority
1. **Local Fallback**: Add Apple Speech or local Whisper transcription
2. **File Management**: Implement audio file cleanup strategies
3. **Background Support**: Add proper background recording entitlements
4. **Performance**: Optimize for large datasets

### Low Priority
1. **Audio Visualization**: Add waveform or level meters
2. **Export Functionality**: Allow session export
3. **Search**: Full-text search across transcriptions
4. **Widget**: iOS widget for quick recording

## Technical Debt

### Code Quality
- Some methods are quite long (rotateSegment, stopRecording)
- Error handling could be more consistent
- Missing comprehensive documentation in some areas

### Architecture
- TranscriptionService could be more modular
- UI and business logic could be better separated
- Missing proper dependency injection

### Performance
- No caching strategy for transcriptions
- File I/O could be optimized
- Memory usage not monitored

## Deployment Considerations

### Production Readiness
- API key security needs improvement
- Error handling needs enhancement
- Performance testing required
- Background recording entitlements needed

### App Store Requirements
- Privacy policy needed for microphone usage
- App review guidelines compliance
- Accessibility features required
- Localization support needed

## Troubleshooting Guide

### Common Issues
1. **Recording doesn't start**: Check microphone permissions
2. **Transcription fails**: Verify API key and network connection
3. **App crashes**: Check Info.plist configuration
4. **Files not saving**: Verify SwiftData context setup

### Debug Information
- Audio session state available in AudioRecorderManager
- Transcription status tracked in Transcription objects
- File URLs stored in AudioSegment objects
- Error messages stored in Transcription.error

## API Reference

### AudioRecorderManager
```swift
// Public interface
func startRecording()
func stopRecording()
func pauseRecording()
func setModelContext(_ context: ModelContext)

// Published properties
@Published var isRecording: Bool
@Published var error: Error?
@Published var permissionDenied: Bool
@Published var segments: [(url: URL, startTime: Date)]
```

### TranscriptionService
```swift
// Public interface
func transcribe(segment: AudioSegment, context: ModelContext, completion: @escaping (Transcription?) -> Void)

// Private methods
private func sendToBackend(segment: AudioSegment, completion: @escaping (Result<String, Error>) -> Void)
private func isNetworkError(_ error: Error) -> Bool
```

This reference guide should be updated as the project evolves. Each major change should be documented here for future reference. 