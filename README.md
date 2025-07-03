# TwinmindRecorder - iOS Audio Recording & Transcription App

A robust iOS audio recording application that handles real-world audio challenges, integrates with backend transcription services, and efficiently manages large datasets with SwiftData.

## Features

### Core Functionality
- **Real-time Audio Recording**: High-quality audio recording using AVAudioEngine
- **Automatic Segmentation**: Splits recordings into configurable 30-second segments
- **Backend Transcription**: Integrates with OpenAI Whisper API for real-time transcription
- **Data Persistence**: Uses SwiftData for efficient session and segment management
- **Background Recording**: Supports recording continuation when app enters background
- **Error Handling**: Robust handling of interruptions, route changes, and network failures

### Audio System Features
- **Audio Session Management**: Properly configured for recording with appropriate categories
- **Route Change Handling**: Gracefully handles headphones, Bluetooth connections, etc.
- **Interruption Recovery**: Automatically pauses/resumes during phone calls, notifications
- **Permission Management**: Secure microphone access with user-friendly prompts

### Data Management
- **SwiftData Integration**: Scalable data model for 1000+ sessions and 10,000+ segments
- **Session Management**: Organize recordings by date with metadata
- **Segment Tracking**: Individual audio chunks with transcription status
- **Transcription Storage**: Complete transcription history with error tracking

## Architecture

### Data Models
- `RecordingSession`: Represents a recording session with date, duration, and segments
- `AudioSegment`: Individual 30-second audio chunks with file URLs and metadata
- `Transcription`: Stores transcription text, status, and error information

### Core Components
- `AudioRecorderManager`: Handles audio recording, segmentation, and session management
- `TranscriptionService`: Manages API calls to OpenAI Whisper and result processing
- SwiftData Context: Provides data persistence and relationship management

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ (for AVAudioApplication API)
- OpenAI API key

### Installation
1. Clone the repository
2. Open `TwinmindRecorder.xcodeproj` in Xcode
3. Add your OpenAI API key to `Info.plist`:
   ```xml
   <key>OPENAI_API_KEY</key>
   <string>your-api-key-here</string>
   ```
4. Build and run the project

### Configuration
- **Segment Duration**: Configurable in `AudioRecorderManager.segmentDuration`
- **Audio Quality**: Adjustable in `beginRecordingSegment()` method
- **API Endpoint**: Modify in `TranscriptionService.sendToBackend()`

## Usage

### Recording
1. Tap the record button to start recording
2. Audio is automatically segmented every 30 seconds
3. Each segment is immediately sent for transcription
4. Tap stop to end the recording session

### Viewing Sessions
- Sessions are automatically saved and listed by date
- Tap a session to view its segments and transcriptions
- Transcription status is shown in real-time

### Error Handling
- Network failures are queued for retry
- Permission denials show user-friendly messages
- Audio interruptions are handled automatically

## Technical Details

### Audio Processing
- **Format**: M4A (configurable)
- **Sample Rate**: Device default (typically 44.1kHz)
- **Bit Depth**: 16-bit (configurable)
- **Buffer Size**: 1024 samples

### API Integration
- **Endpoint**: OpenAI Whisper API
- **Authentication**: Bearer token from Info.plist
- **Request Format**: Multipart/form-data
- **Response**: JSON with transcribed text

### Data Persistence
- **Database**: SwiftData with automatic migrations
- **File Storage**: Temporary directory with unique naming
- **Relationships**: Proper cascade deletion and nullification

## Security Considerations

### API Key Management
- API keys stored in Info.plist (excluded from git)
- No hardcoded secrets in source code
- Consider Keychain for production deployments

### Data Privacy
- Audio files stored locally only
- Transcriptions processed through secure API
- No data sent to third parties except OpenAI

## Performance Optimizations

### Memory Management
- Audio buffers processed in real-time
- Files written directly to disk
- SwiftData lazy loading for large datasets

### Battery Optimization
- Efficient audio session configuration
- Background processing limitations respected
- Minimal network requests with batching

## Known Limitations

### Current Implementation
- No local transcription fallback (planned)
- Limited offline queue management
- Basic error recovery mechanisms

### Platform Constraints
- iOS 17.0+ required for latest audio APIs
- Background recording requires entitlements
- File size limitations on older devices

## Future Enhancements

### Planned Features
- Local transcription fallback (Apple Speech/Whisper)
- Advanced offline queue management
- Audio visualization and level meters
- Export functionality for sessions
- Full-text search across transcriptions
- iOS widget for quick recording access

### Performance Improvements
- Concurrent transcription processing
- Intelligent file cleanup strategies
- Enhanced error recovery mechanisms
- Background task optimization

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with proper documentation
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the known limitations section
2. Review the technical documentation
3. Open an issue with detailed reproduction steps
4. Include device and iOS version information 