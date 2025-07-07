//
//  UnitTests.swift
//  TwinmindRecorderTests
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import Testing
import SwiftData
import Foundation
@testable import TwinmindRecorder

struct UnitTests {
    
    // MARK: - Data Model Tests
    
    @Test("RecordingSession initialization and properties") func testRecordingSessionInitialization() throws {
        let date = Date()
        let session = RecordingSession(name: "Test Session", date: date, duration: 120.0)
        
        #expect(session.name == "Test Session")
        #expect(session.date == date)
        #expect(session.duration == 120.0)
        #expect(session.segments.isEmpty)
        #expect(session.id != UUID())
    }
    
    @Test("RecordingSession default name generation") func testRecordingSessionDefaultName() throws {
        let date = Date()
        let session = RecordingSession(name: nil, date: date, duration: 0)
        
        #expect(session.name.contains("Session on"))
        #expect(session.name.contains(DateFormatter().string(from: date)))
    }
    
    @Test("AudioSegment initialization and properties") func testAudioSegmentInitialization() throws {
        let startTime: TimeInterval = 100.0
        let duration: TimeInterval = 30.0
        let fileURL = URL(fileURLWithPath: "/test/audio.wav")
        let segment = AudioSegment(startTime: startTime, duration: duration, fileURL: fileURL)
        
        #expect(segment.startTime == startTime)
        #expect(segment.duration == duration)
        #expect(segment.fileURL == fileURL)
        #expect(segment.transcription == nil)
        #expect(segment.id != UUID())
    }
    
    @Test("Transcription initialization and status") func testTranscriptionInitialization() throws {
        let transcription = Transcription(text: "Hello world", status: .completed)
        
        #expect(transcription.text == "Hello world")
        #expect(transcription.status == .completed)
        #expect(transcription.error == nil)
        #expect(transcription.id != UUID())
    }
    
    @Test("Transcription status transitions") func testTranscriptionStatusTransitions() throws {
        let transcription = Transcription(text: "", status: .pending)
        
        #expect(transcription.status == .pending)
        
        transcription.status = .processing
        #expect(transcription.status == .processing)
        
        transcription.status = .completed
        #expect(transcription.status == .completed)
        
        transcription.status = .failed
        #expect(transcription.status == .failed)
    }
    
    // MARK: - AudioBuffer Tests
    
    @Test("AudioBuffer singleton pattern") func testAudioBufferSingleton() throws {
        let buffer1 = AudioBuffer.shared
        let buffer2 = AudioBuffer.shared
        
        #expect(buffer1 === buffer2)
    }
    
    @Test("AudioBuffer session creation and management") func testAudioBufferSessionManagement() throws {
        let buffer = AudioBuffer.shared
        let sessionId = UUID()
        
        // Test buffer creation
        buffer.createBuffer(for: sessionId)
        
        // Test adding audio data
        let testData = Data(repeating: 0, count: 1024)
        buffer.addAudioData(testData, for: sessionId, segmentIndex: 0)
        
        // Test retrieving audio data
        let retrievedData = buffer.getAudioData(for: sessionId, segmentIndex: 0)
        #expect(retrievedData == testData)
    }
    
    @Test("AudioBuffer memory management") func testAudioBufferMemoryManagement() throws {
        let buffer = AudioBuffer.shared
        
        // Create multiple sessions
        for i in 0..<15 {
            let sessionId = UUID()
            buffer.createBuffer(for: sessionId)
            buffer.addAudioData(Data(repeating: UInt8(i), count: 1024), for: sessionId, segmentIndex: 0)
        }
        
        // Test memory stats
        let stats = buffer.getMemoryStats()
        #expect(stats["sessionsInMemory"] as? Int == 10) // Should be limited to maxSessionsInMemory
        
        // Test clearing buffers
        buffer.clearAllBuffers()
        let statsAfterClear = buffer.getMemoryStats()
        #expect(statsAfterClear["sessionsInMemory"] as? Int == 0)
    }
    
    @Test("AudioBuffer segment management") func testAudioBufferSegmentManagement() throws {
        let buffer = AudioBuffer.shared
        let sessionId = UUID()
        
        buffer.createBuffer(for: sessionId)
        
        // Add multiple segments
        for i in 0..<5 {
            let segmentData = Data(repeating: UInt8(i), count: 1024)
            buffer.addAudioData(segmentData, for: sessionId, segmentIndex: i)
        }
        
        // Test getting all segments
        let allSegments = buffer.getAllSegments(for: sessionId)
        #expect(allSegments.count == 5)
        
        // Test individual segment retrieval
        for i in 0..<5 {
            let segmentData = buffer.getAudioData(for: sessionId, segmentIndex: i)
            #expect(segmentData?.first == UInt8(i))
        }
    }
    
    // MARK: - Business Logic Tests
    
    @Test("Session duration calculation") func testSessionDurationCalculation() throws {
        let session = RecordingSession(name: "Test", date: Date(), duration: 0)
        
        // Add segments with different durations
        let segment1 = AudioSegment(startTime: 0, duration: 30)
        let segment2 = AudioSegment(startTime: 30, duration: 45)
        let segment3 = AudioSegment(startTime: 75, duration: 15)
        
        session.segments = [segment1, segment2, segment3]
        
        // Calculate total duration
        let totalDuration = session.segments.reduce(0) { $0 + $1.duration }
        #expect(totalDuration == 90.0)
    }
    
    @Test("Transcription completion rate calculation") func testTranscriptionCompletionRate() throws {
        let session = RecordingSession(name: "Test", date: Date(), duration: 0)
        
        // Create segments with different transcription statuses
        let segment1 = AudioSegment(startTime: 0, duration: 30)
        segment1.transcription = Transcription(text: "Hello", status: .completed)
        
        let segment2 = AudioSegment(startTime: 30, duration: 30)
        segment2.transcription = Transcription(text: "", status: .processing)
        
        let segment3 = AudioSegment(startTime: 60, duration: 30)
        segment3.transcription = Transcription(text: "", status: .failed)
        
        let segment4 = AudioSegment(startTime: 90, duration: 30)
        // No transcription
        
        session.segments = [segment1, segment2, segment3, segment4]
        
        // Calculate completion rates
        let totalSegments = session.segments.count
        let completedTranscriptions = session.segments.filter { $0.transcription?.status == .completed }.count
        let processingTranscriptions = session.segments.filter { $0.transcription?.status == .processing }.count
        let failedTranscriptions = session.segments.filter { $0.transcription?.status == .failed }.count
        let noTranscription = session.segments.filter { $0.transcription == nil }.count
        
        #expect(totalSegments == 4)
        #expect(completedTranscriptions == 1)
        #expect(processingTranscriptions == 1)
        #expect(failedTranscriptions == 1)
        #expect(noTranscription == 1)
    }
    
    @Test("Date grouping logic") func testDateGroupingLogic() throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Test today
        #expect(calendar.isDateInToday(now))
        
        // Test yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        #expect(calendar.isDateInYesterday(yesterday))
        
        // Test this week
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        #expect(threeDaysAgo >= weekAgo)
        
        // Test earlier
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        #expect(twoWeeksAgo < weekAgo)
    }
    
    @Test("Search and filter logic") func testSearchAndFilterLogic() throws {
        let sessions = [
            RecordingSession(name: "Meeting with John", date: Date(), duration: 120),
            RecordingSession(name: "Interview with Sarah", date: Date(), duration: 180),
            RecordingSession(name: "Daily standup", date: Date(), duration: 30),
            RecordingSession(name: "Product review", date: Date(), duration: 90)
        ]
        
        // Test search by name
        let searchText = "meeting"
        let searchResults = sessions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        #expect(searchResults.count == 1)
        #expect(searchResults.first?.name == "Meeting with John")
        
        // Test filter by duration
        let minDuration: TimeInterval = 60
        let durationResults = sessions.filter { $0.duration >= minDuration }
        #expect(durationResults.count == 3)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Invalid audio segment handling") func testInvalidAudioSegmentHandling() throws {
        let segment = AudioSegment(startTime: -10, duration: -5) // Invalid values
        
        #expect(segment.startTime == -10)
        #expect(segment.duration == -5)
        
        // Test with nil file URL
        let segmentWithNilURL = AudioSegment(startTime: 0, duration: 30, fileURL: nil)
        #expect(segmentWithNilURL.fileURL == nil)
    }
    
    @Test("Empty transcription handling") func testEmptyTranscriptionHandling() throws {
        let transcription = Transcription(text: "", status: .completed)
        
        #expect(transcription.text.isEmpty)
        #expect(transcription.status == .completed)
        
        // Test with error
        transcription.error = "Network timeout"
        #expect(transcription.error == "Network timeout")
    }
    
    @Test("AudioBuffer error handling") func testAudioBufferErrorHandling() throws {
        let buffer = AudioBuffer.shared
        let nonExistentSessionId = UUID()
        
        // Test getting data for non-existent session
        let data = buffer.getAudioData(for: nonExistentSessionId, segmentIndex: 0)
        #expect(data == nil)
        
        // Test getting all segments for non-existent session
        let allSegments = buffer.getAllSegments(for: nonExistentSessionId)
        #expect(allSegments.isEmpty)
    }
} 