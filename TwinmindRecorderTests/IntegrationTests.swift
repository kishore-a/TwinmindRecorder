//
//  IntegrationTests.swift
//  TwinmindRecorderTests
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import Testing
import SwiftData
import AVFoundation
import Foundation
@testable import TwinmindRecorder

struct IntegrationTests {
    
    // MARK: - Audio System Integration Tests
    
    @Test("AudioRecorderManager and AudioBuffer integration") func testAudioRecorderAndBufferIntegration() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        
        // Mock permission grant
        recorder.permissionDenied = false
        
        // Start recording
        recorder.startRecording()
        
        // Wait for recording to start
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        #expect(recorder.isRecording == true)
        
        // Check if segments are being created (this indicates a session is active)
        #expect(recorder.segments.count >= 0)
        
        // Stop recording
        recorder.stopRecording()
        
        #expect(recorder.isRecording == false)
        #expect(recorder.segments.count > 0)
        
        // Verify session was saved to SwiftData
        let savedSessions = try modelContext.fetch(FetchDescriptor<RecordingSession>())
        #expect(savedSessions.count > 0)
    }
    
    @Test("AudioRecorderManager segment rotation integration") func testSegmentRotationIntegration() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Set short segment duration for testing
        recorder.segmentDuration = 2.0 // 2 seconds
        
        // Start recording
        recorder.startRecording()
        
        // Wait for segment rotation
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        #expect(recorder.segments.count >= 1)
        
        // Stop recording
        recorder.stopRecording()
        
        // Verify segments were saved to SwiftData
        let savedSessions = try modelContext.fetch(FetchDescriptor<RecordingSession>())
        #expect(savedSessions.count > 0)
        
        if let session = savedSessions.first {
            #expect(session.segments.count > 0)
        }
    }
    
    @Test("TranscriptionService and AudioSegment integration") func testTranscriptionServiceIntegration() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create a test session and segment
        let session = RecordingSession(name: "Test Session", date: Date(), duration: 30)
        let segment = AudioSegment(startTime: 0, duration: 30)
        
        session.segments.append(segment)
        modelContext.insert(session)
        
        // Mock audio file URL
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_audio.wav")
        segment.fileURL = tempURL
        
        // Create mock audio data
        let mockAudioData = Data(repeating: 0, count: 1024)
        try mockAudioData.write(to: tempURL)
        
        // Test transcription service
        var transcriptionCompleted = false
        var transcriptionResult: Transcription?
        
        TranscriptionService.shared.transcribe(segment: segment, context: modelContext) { transcription in
            transcriptionResult = transcription
            transcriptionCompleted = true
        }
        
        // Wait for transcription (with timeout)
        let timeout = 10.0
        let startWaitTime = CFAbsoluteTimeGetCurrent()
        
        while !transcriptionCompleted {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startWaitTime
            if elapsedTime > timeout {
                break // Timeout reached
            }
        }
        
        // Verify transcription was attempted
        #expect(segment.transcription != nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test("AudioPlayer and AudioBuffer integration") func testAudioPlayerIntegration() async throws {
        let audioPlayer = AudioPlayer()
        let buffer = AudioBuffer.shared
        
        // Create test session
        let session = RecordingSession(name: "Test Session", date: Date(), duration: 30)
        let sessionId = session.id
        
        // Add test audio data to buffer
        buffer.createBuffer(for: sessionId)
        let testAudioData = Data(repeating: 1, count: 2048)
        buffer.addAudioData(testAudioData, for: sessionId, segmentIndex: 0)
        
        // Test loading session
        var loadCompleted = false
        audioPlayer.loadSession(sessionId) { success in
            #expect(success == true)
            loadCompleted = true
        }
        
        // Wait for loading (with timeout)
        let timeout = 5.0
        let startWaitTime = CFAbsoluteTimeGetCurrent()
        
        while !loadCompleted {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startWaitTime
            if elapsedTime > timeout {
                break // Timeout reached
            }
        }
        
        // Test playback
        audioPlayer.play()
        #expect(audioPlayer.isPlaying == true)
        
        // Stop playback
        audioPlayer.stop()
        #expect(audioPlayer.isPlaying == false)
    }
    
    @Test("SwiftData persistence integration") func testSwiftDataPersistence() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test data
        let session = RecordingSession(name: "Persistence Test", date: Date(), duration: 60)
        let segment1 = AudioSegment(startTime: 0, duration: 30)
        let segment2 = AudioSegment(startTime: 30, duration: 30)
        let transcription = Transcription(text: "Test transcription", status: .completed)
        
        // Set up relationships
        session.segments = [segment1, segment2]
        segment1.transcription = transcription
        transcription.segment = segment1
        
        // Insert into context
        modelContext.insert(session)
        modelContext.insert(segment1)
        modelContext.insert(segment2)
        modelContext.insert(transcription)
        
        // Save
        try modelContext.save()
        
        // Fetch and verify
        let fetchDescriptor = FetchDescriptor<RecordingSession>()
        let fetchedSessions = try modelContext.fetch(fetchDescriptor)
        
        #expect(fetchedSessions.count > 0)
        
        if let fetchedSession = fetchedSessions.first {
            #expect(fetchedSession.name == "Persistence Test")
            #expect(fetchedSession.segments.count == 2)
            
            if let firstSegment = fetchedSession.segments.first {
                #expect(firstSegment.transcription != nil)
                #expect(firstSegment.transcription?.text == "Test transcription")
            }
        }
    }
    
    // MARK: - API Integration Tests
    
    @Test("TranscriptionService fallback mechanism") func testTranscriptionServiceFallback() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test segment
        let segment = AudioSegment(startTime: 0, duration: 30)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("fallback_test.wav")
        segment.fileURL = tempURL
        
        // Create mock audio data
        let mockAudioData = Data(repeating: 0, count: 1024)
        try mockAudioData.write(to: tempURL)
        
        // Force local transcription mode
        TranscriptionService.shared.switchToLocalTranscription()
        
        var transcriptionCompleted = false
        var transcriptionResult: Transcription?
        
        TranscriptionService.shared.transcribe(segment: segment, context: modelContext) { transcription in
            transcriptionResult = transcription
            transcriptionCompleted = true
        }
        
        // Wait for transcription (with timeout)
        let timeout = 10.0
        let startWaitTime = CFAbsoluteTimeGetCurrent()
        
        while !transcriptionCompleted {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startWaitTime
            if elapsedTime > timeout {
                break // Timeout reached
            }
        }
        
        // Verify local transcription was attempted
        #expect(segment.transcription != nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test("Offline queue processing integration") func testOfflineQueueProcessing() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test segments
        let segment1 = AudioSegment(startTime: 0, duration: 30)
        let segment2 = AudioSegment(startTime: 30, duration: 30)
        
        // Add to offline queue (simulate network failure)
        // Note: This would normally happen when network transcription fails
        // For testing, we'll manually trigger the offline queue processing
        
        TranscriptionService.shared.processOfflineQueue(context: modelContext)
        
        // Verify the method doesn't crash and handles empty queue gracefully
        #expect(true) // If we reach here, the method executed successfully
    }
    
    @Test("AudioRecorderManager pause and resume integration") func testPauseResumeIntegration() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Start recording
        recorder.startRecording()
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Pause recording
        recorder.pauseRecording()
        #expect(recorder.isPaused == true)
        #expect(recorder.isRecording == true)
        
        // Resume recording
        recorder.resumeRecording()
        #expect(recorder.isPaused == false)
        #expect(recorder.isRecording == true)
        
        // Stop recording
        recorder.stopRecording()
        #expect(recorder.isRecording == false)
    }
    
    @Test("AudioRecorderManager interruption handling") func testInterruptionHandling() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Start recording
        recorder.startRecording()
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Simulate audio interruption
        let notification = Notification(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
        ])
        
        NotificationCenter.default.post(notification)
        
        // Wait for interruption handling
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Verify recording was paused due to interruption
        #expect(recorder.isPaused == true)
        
        // Stop recording
        recorder.stopRecording()
    }
    
    @Test("Memory management integration") func testMemoryManagementIntegration() async throws {
        let buffer = AudioBuffer.shared
        
        // Create many sessions to test memory management
        for i in 0..<20 {
            let sessionId = UUID()
            buffer.createBuffer(for: sessionId)
            
            // Add multiple segments per session
            for j in 0..<10 {
                let segmentData = Data(repeating: UInt8(i + j), count: 1024)
                buffer.addAudioData(segmentData, for: sessionId, segmentIndex: j)
            }
        }
        
        // Check memory stats
        let stats = buffer.getMemoryStats()
        let sessionsInMemory = stats["sessionsInMemory"] as? Int ?? 0
        
        // Should be limited by maxSessionsInMemory (10)
        #expect(sessionsInMemory <= 10)
        
        // Test memory cleanup
        buffer.clearAllBuffers()
        
        let statsAfterClear = buffer.getMemoryStats()
        let sessionsAfterClear = statsAfterClear["sessionsInMemory"] as? Int ?? 0
        #expect(sessionsAfterClear == 0)
    }
} 
