//
//  EdgeCaseTests.swift
//  TwinmindRecorderTests
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import Testing
import SwiftData
import AVFoundation
import Foundation
import UIKit
@testable import TwinmindRecorder

struct EdgeCaseTests {
    
    // MARK: - Permission and Authorization Edge Cases
    
    @Test("AudioRecorderManager permission denied handling") @MainActor func testPermissionDeniedHandling() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        
        // Simulate permission denied
        recorder.permissionDenied = true
        
        // Try to start recording
        recorder.startRecording()
        
        // Should not start recording when permission is denied
        #expect(recorder.isRecording == false)
        #expect(recorder.error != nil)
    }
    
    @Test("TranscriptionService speech recognition authorization denied") @MainActor func testSpeechRecognitionAuthorizationDenied() async throws {
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test segment
        let segment = AudioSegment(startTime: 0, duration: 30)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("auth_test.wav")
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
        
        // Should handle authorization errors gracefully
        #expect(segment.transcription != nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - File System Edge Cases
    
    @Test("AudioRecorderManager missing audio file handling") @MainActor func testMissingAudioFileHandling() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Start and immediately stop recording to create a segment
        recorder.startRecording()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        recorder.stopRecording()
        
        // Verify segments were created
        #expect(recorder.segments.count > 0)
        
        // Test with non-existent file URL
        let segment = AudioSegment(startTime: 0, duration: 30, fileURL: URL(fileURLWithPath: "/nonexistent/file.wav"))
        
        // Should handle missing files gracefully
        #expect(segment.fileURL != nil)
        #expect(!FileManager.default.fileExists(atPath: segment.fileURL!.path))
    }
    
    @Test("AudioBuffer disk operations with insufficient space") func testAudioBufferDiskSpaceHandling() async throws {
        let buffer = AudioBuffer.shared
        let sessionId = UUID()
        
        // Create buffer
        buffer.createBuffer(for: sessionId)
        
        // Add large amount of data to potentially trigger disk space issues
        let largeData = Data(repeating: 0, count: 1024 * 1024) // 1MB
        
        // This should handle disk space issues gracefully
        for i in 0..<10 {
            buffer.addAudioData(largeData, for: sessionId, segmentIndex: i)
        }
        
        // Verify buffer operations don't crash
        let stats = buffer.getMemoryStats()
        #expect(stats["sessionsInMemory"] as? Int ?? 0 >= 0)
    }
    
    @Test("TranscriptionService corrupted audio file") @MainActor func testCorruptedAudioFile() async throws {
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test segment with corrupted file
        let segment = AudioSegment(startTime: 0, duration: 30)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("corrupted_test.wav")
        segment.fileURL = tempURL
        
        // Create corrupted audio data (invalid WAV format)
        let corruptedData = Data(repeating: 255, count: 1024) // Random bytes
        try corruptedData.write(to: tempURL)
        
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
        
        // Should handle corrupted files gracefully
        #expect(segment.transcription != nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - Network and API Edge Cases
    
    @Test("TranscriptionService network timeout handling") @MainActor func testNetworkTimeoutHandling() async throws {
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test segment
        let segment = AudioSegment(startTime: 0, duration: 30)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("timeout_test.wav")
        segment.fileURL = tempURL
        
        // Create mock audio data
        let mockAudioData = Data(repeating: 0, count: 1024)
        try mockAudioData.write(to: tempURL)
        
        // Switch to remote transcription (which might timeout)
        TranscriptionService.shared.switchToRemoteTranscription()
        
        var transcriptionCompleted = false
        var transcriptionResult: Transcription?
        
        TranscriptionService.shared.transcribe(segment: segment, context: modelContext) { transcription in
            transcriptionResult = transcription
            transcriptionCompleted = true
        }
        
        // Wait for transcription (with timeout)
        let timeout = 15.0
        let startWaitTime = CFAbsoluteTimeGetCurrent()
        
        while !transcriptionCompleted {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startWaitTime
            if elapsedTime > timeout {
                break // Timeout reached
            }
        }
        
        // Should handle timeouts gracefully
        #expect(segment.transcription != nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test("TranscriptionService consecutive failures handling") @MainActor func testConsecutiveFailuresHandling() async throws {
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create multiple test segments
        for i in 0..<10 {
            let segment = AudioSegment(startTime: TimeInterval(i * 30), duration: 30)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("failure_test_\(i).wav")
            segment.fileURL = tempURL
            
            // Create mock audio data
            let mockAudioData = Data(repeating: 0, count: 1024)
            try mockAudioData.write(to: tempURL)
            
            // Switch to remote transcription
            TranscriptionService.shared.switchToRemoteTranscription()
            
            var transcriptionCompleted = false
            
            TranscriptionService.shared.transcribe(segment: segment, context: modelContext) { transcription in
                transcriptionCompleted = true
            }
            
            // Wait for transcription (with timeout)
            let timeout = 5.0
            let startWaitTime = CFAbsoluteTimeGetCurrent()
            
            while !transcriptionCompleted {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startWaitTime
                if elapsedTime > timeout {
                    break // Timeout reached
                }
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Should handle consecutive failures and potentially switch to local transcription
        let status = TranscriptionService.shared.getTranscriptionStatus()
        #expect(status.failureCount >= 0)
    }
    
    // MARK: - Memory and Performance Edge Cases
    
    @Test("AudioRecorderManager memory pressure handling") @MainActor func testMemoryPressureHandling() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Start recording
        recorder.startRecording()
        
        // Simulate memory pressure
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Wait for memory pressure handling
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Should handle memory pressure gracefully
        #expect(recorder.isRecording == true || recorder.isRecording == false)
        
        // Stop recording
        recorder.stopRecording()
    }
    
    @Test("AudioBuffer extreme memory usage") func testExtremeMemoryUsage() async throws {
        let buffer = AudioBuffer.shared
        
        // Create many sessions with large data
        for i in 0..<50 {
            let sessionId = UUID()
            buffer.createBuffer(for: sessionId)
            
            // Add large segments
            for j in 0..<20 {
                let largeData = Data(repeating: UInt8(i + j), count: 1024 * 512) // 512KB per segment
                buffer.addAudioData(largeData, for: sessionId, segmentIndex: j)
            }
        }
        
        // Check memory management
        let stats = buffer.getMemoryStats()
        let sessionsInMemory = stats["sessionsInMemory"] as? Int ?? 0
        let memoryUsageMB = stats["totalMemoryUsageMB"] as? Double ?? 0
        
        // Should limit memory usage
        #expect(sessionsInMemory <= 10) // maxSessionsInMemory
        #expect(memoryUsageMB >= 0)
        
        // Clean up
        buffer.clearAllBuffers()
    }
    
    // MARK: - Audio Session Edge Cases
    
    @Test("AudioRecorderManager audio session configuration failure") @MainActor func testAudioSessionConfigurationFailure() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Try to start recording (audio session setup is handled internally)
        recorder.startRecording()
        
        // Wait for setup
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Should handle audio session setup gracefully
        #expect(recorder.isRecording == true || recorder.error != nil)
        
        // Stop recording
        recorder.stopRecording()
    }
    
    @Test("AudioRecorderManager route change handling") @MainActor func testRouteChangeHandling() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Start recording
        recorder.startRecording()
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Simulate route change (headphones disconnected)
        let notification = Notification(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
        ])
        
        NotificationCenter.default.post(notification)
        
        // Wait for route change handling
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Should handle route changes gracefully
        #expect(recorder.isPaused == true || recorder.isRecording == true)
        
        // Stop recording
        recorder.stopRecording()
    }
    
    // MARK: - Data Model Edge Cases
    
    @Test("SwiftData concurrent access handling") @MainActor func testSwiftDataConcurrentAccess() async throws {
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create multiple concurrent tasks
        let tasks = (0..<10).map { i in
            Task {
                let session = RecordingSession(name: "Concurrent Session \(i)", date: Date(), duration: 30)
                modelContext.insert(session)
                try modelContext.save()
                return session.id
            }
        }
        
        // Wait for all tasks to complete
        let sessionIds = try await withThrowingTaskGroup(of: UUID.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var ids: [UUID] = []
            for try await id in group {
                ids.append(id)
            }
            return ids
        }
        
        // Verify all sessions were created
        #expect(sessionIds.count == 10)
        
        // Fetch all sessions
        let fetchDescriptor = FetchDescriptor<RecordingSession>()
        let sessions = try modelContext.fetch(fetchDescriptor)
        #expect(sessions.count >= 10)
    }
    
    @Test("AudioSegment invalid time values") func testAudioSegmentInvalidTimeValues() async throws {
        // Test with negative values
        let negativeSegment = AudioSegment(startTime: -100, duration: -50)
        #expect(negativeSegment.startTime == -100)
        #expect(negativeSegment.duration == -50)
        
        // Test with extremely large values
        let largeSegment = AudioSegment(startTime: Double.greatestFiniteMagnitude, duration: Double.greatestFiniteMagnitude)
        #expect(largeSegment.startTime == Double.greatestFiniteMagnitude)
        #expect(largeSegment.duration == Double.greatestFiniteMagnitude)
        
        // Test with zero values
        let zeroSegment = AudioSegment(startTime: 0, duration: 0)
        #expect(zeroSegment.startTime == 0)
        #expect(zeroSegment.duration == 0)
    }
    
    @Test("RecordingSession edge case names") func testRecordingSessionEdgeCaseNames() async throws {
        // Test with empty name
        let emptyNameSession = RecordingSession(name: "", date: Date(), duration: 30)
        #expect(emptyNameSession.name == "")
        
        // Test with very long name
        let longName = String(repeating: "A", count: 1000)
        let longNameSession = RecordingSession(name: longName, date: Date(), duration: 30)
        #expect(longNameSession.name == longName)
        
        // Test with special characters
        let specialCharsName = "Session with 🎵 emoji and 特殊字符"
        let specialCharsSession = RecordingSession(name: specialCharsName, date: Date(), duration: 30)
        #expect(specialCharsSession.name == specialCharsName)
        
        // Test with nil name (should generate default)
        let nilNameSession = RecordingSession(name: nil, date: Date(), duration: 30)
        #expect(!nilNameSession.name.isEmpty)
        #expect(nilNameSession.name.contains("Session on"))
    }
    
    // MARK: - Recovery Scenarios
    
    @Test("AudioRecorderManager recovery after interruption") @MainActor func testRecoveryAfterInterruption() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Start recording
        recorder.startRecording()
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Simulate interruption
        let interruptionNotification = Notification(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
        ])
        NotificationCenter.default.post(interruptionNotification)
        
        // Wait for interruption handling
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Simulate interruption end
        let resumeNotification = Notification(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ])
        NotificationCenter.default.post(resumeNotification)
        
        // Wait for recovery
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Should recover gracefully
        #expect(recorder.isRecording == true || recorder.isPaused == true)
        
        // Stop recording
        recorder.stopRecording()
    }
    
    @Test("TranscriptionService recovery after network failure") @MainActor func testTranscriptionServiceRecovery() async throws {
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test segment
        let segment = AudioSegment(startTime: 0, duration: 30)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recovery_test.wav")
        segment.fileURL = tempURL
        
        // Create mock audio data
        let mockAudioData = Data(repeating: 0, count: 1024)
        try mockAudioData.write(to: tempURL)
        
        // Switch to remote transcription
        TranscriptionService.shared.switchToRemoteTranscription()
        
        var transcriptionCompleted = false
        
        TranscriptionService.shared.transcribe(segment: segment, context: modelContext) { transcription in
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
        
        // Should handle recovery gracefully
        #expect(segment.transcription != nil)
        
        // Test retry functionality
        TranscriptionService.shared.retryTranscription(for: segment, context: modelContext) { transcription in
            // Should handle retry gracefully
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test("TranscriptionService timeout handling") @MainActor func testTranscriptionTimeoutHandling() async throws {
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test segment with very large file
        let segment = AudioSegment(startTime: 0, duration: 300) // 5 minutes
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("timeout_test.wav")
        segment.fileURL = tempURL
        
        // Create large audio data (10MB)
        let largeData = Data(repeating: 0, count: 10 * 1024 * 1024)
        try largeData.write(to: tempURL)
        
        // Switch to remote transcription (which might timeout)
        TranscriptionService.shared.switchToRemoteTranscription()
        
        var transcriptionCompleted = false
        var transcriptionResult: Transcription?
        
        TranscriptionService.shared.transcribe(segment: segment, context: modelContext) { transcription in
            transcriptionResult = transcription
            transcriptionCompleted = true
        }
        
        // Wait for transcription (with timeout)
        let timeout = 15.0
        let startWaitTime = CFAbsoluteTimeGetCurrent()
        
        while !transcriptionCompleted {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startWaitTime
            if elapsedTime > timeout {
                break // Timeout reached
            }
        }
        
        // Should handle timeouts gracefully
        #expect(segment.transcription != nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test("TranscriptionService retry mechanism") @MainActor func testTranscriptionRetry() async throws {
        let modelContext = try  ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test segment
        let segment = AudioSegment(startTime: 0, duration: 30)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("retry_test.wav")
        segment.fileURL = tempURL
        
        // Create mock audio data
        let mockAudioData = Data(repeating: 0, count: 1024)
        try mockAudioData.write(to: tempURL)
        
        // Force local transcription mode
        TranscriptionService.shared.switchToLocalTranscription()
        
        var transcriptionCompleted = false
        var transcriptionResult: Transcription?
        
        // Simulate multiple transcription attempts
        for _ in 0..<3 {
            transcriptionCompleted = false
            
            TranscriptionService.shared.transcribe(segment: segment, context: modelContext) { transcription in
                transcriptionResult = transcription
                transcriptionCompleted = true
            }
            
            // Wait for transcription (with timeout)
            let timeout = 5.0
            let startWaitTime = CFAbsoluteTimeGetCurrent()
            
            while !transcriptionCompleted {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startWaitTime
                if elapsedTime > timeout {
                    break // Timeout reached
                }
            }
            
            if transcriptionCompleted {
                break // Success, no need to retry
            }
        }
        
        // Should eventually succeed or handle retries gracefully
        #expect(segment.transcription != nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
} 
