//
//  PerformanceTests.swift
//  TwinmindRecorderTests
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import Testing
import SwiftData
import Foundation
@testable import TwinmindRecorder
import UIKit

struct PerformanceTests {
    
    // MARK: - Large Dataset Performance Tests
    
    @Test("SwiftData large dataset insertion performance") func testLargeDatasetInsertion() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create 1000 sessions with multiple segments each
        for i in 0..<1000 {
            let session = RecordingSession(name: "Performance Test Session \(i)", date: Date(), duration: 300)
            
            // Add 10 segments per session
            for j in 0..<10 {
                let segment = AudioSegment(startTime: TimeInterval(j * 30), duration: 30)
                let transcription = Transcription(text: "Transcription for segment \(j)", status: .completed)
                
                segment.transcription = transcription
                transcription.segment = segment
                session.segments.append(segment)
                
                modelContext.insert(segment)
                modelContext.insert(transcription)
            }
            
            modelContext.insert(session)
            
            // Save every 100 sessions to avoid memory issues
            if i % 100 == 0 {
                try modelContext.save()
            }
        }
        
        // Final save
        try modelContext.save()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Verify data was inserted
        let fetchDescriptor = FetchDescriptor<RecordingSession>()
        let sessions = try modelContext.fetch(fetchDescriptor)
        
        #expect(sessions.count >= 1000)
        #expect(duration < 30.0) // Should complete within 30 seconds
        
        print("✅ Inserted \(sessions.count) sessions in \(String(format: "%.2f", duration)) seconds")
    }
    
    @Test("SwiftData large dataset query performance") func testLargeDatasetQueryPerformance() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // First, create test data
        for i in 0..<500 {
            let session = RecordingSession(name: "Query Test Session \(i)", date: Date(), duration: 300)
            
            for j in 0..<5 {
                let segment = AudioSegment(startTime: TimeInterval(j * 30), duration: 30)
                session.segments.append(segment)
                modelContext.insert(segment)
            }
            
            modelContext.insert(session)
        }
        
        try modelContext.save()
        
        // Test query performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let fetchDescriptor = FetchDescriptor<RecordingSession>()
        let sessions = try modelContext.fetch(fetchDescriptor)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(sessions.count >= 500)
        #expect(duration < 5.0) // Should complete within 5 seconds
        
        print("✅ Queried \(sessions.count) sessions in \(String(format: "%.3f", duration)) seconds")
    }
    
    @Test("AudioBuffer large dataset performance") func testAudioBufferLargeDataset() async throws {
        let buffer = AudioBuffer.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create 100 sessions with large audio data
        for i in 0..<100 {
            let sessionId = UUID()
            buffer.createBuffer(for: sessionId)
            
            // Add 50 segments per session with 1KB each
            for j in 0..<50 {
                let audioData = Data(repeating: UInt8(i + j), count: 1024)
                buffer.addAudioData(audioData, for: sessionId, segmentIndex: j)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Check memory stats
        let stats = buffer.getMemoryStats()
        let sessionsInMemory = stats["sessionsInMemory"] as? Int ?? 0
        let memoryUsageMB = stats["totalMemoryUsageMB"] as? Double ?? 0
        
        #expect(sessionsInMemory <= 10) // Should respect memory limit
        #expect(duration < 10.0) // Should complete within 10 seconds
        #expect(memoryUsageMB >= 0)
        
        print("✅ Created \(100) sessions with \(50) segments each in \(String(format: "%.3f", duration)) seconds")
        print("✅ Memory usage: \(String(format: "%.2f", memoryUsageMB)) MB, Sessions in memory: \(sessionsInMemory)")
        
        // Clean up
        buffer.clearAllBuffers()
    }
    
    @Test("AudioBuffer retrieval performance") func testAudioBufferRetrievalPerformance() async throws {
        let buffer = AudioBuffer.shared
        
        // Create test data
        let sessionId = UUID()
        buffer.createBuffer(for: sessionId)
        
        // Add 100 segments
        for i in 0..<100 {
            let audioData = Data(repeating: UInt8(i), count: 1024)
            buffer.addAudioData(audioData, for: sessionId, segmentIndex: i)
        }
        
        // Test retrieval performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let allSegments = buffer.getAllSegments(for: sessionId)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(allSegments.count == 100)
        #expect(duration < 1.0) // Should complete within 1 second
        
        print("✅ Retrieved \(allSegments.count) segments in \(String(format: "%.3f", duration)) seconds")
        
        // Test individual segment retrieval
        let individualStartTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<100 {
            let segmentData = buffer.getAudioData(for: sessionId, segmentIndex: i)
            #expect(segmentData != nil)
        }
        
        let individualEndTime = CFAbsoluteTimeGetCurrent()
        let individualDuration = individualEndTime - individualStartTime
        
        #expect(individualDuration < 2.0) // Should complete within 2 seconds
        
        print("✅ Retrieved \(100) individual segments in \(String(format: "%.3f", individualDuration)) seconds")
        
        // Clean up
        buffer.clearAllBuffers()
    }
    
    // MARK: - Memory Usage Performance Tests
    
    @Test("Memory usage under load") func testMemoryUsageUnderLoad() async throws {
        let buffer = AudioBuffer.shared
        
        // Monitor memory usage
        let initialStats = buffer.getMemoryStats()
        let initialMemoryMB = initialStats["totalMemoryUsageMB"] as? Double ?? 0
        
        // Create load
        for i in 0..<20 {
            let sessionId = UUID()
            buffer.createBuffer(for: sessionId)
            
            // Add large segments
            for j in 0..<10 {
                let largeData = Data(repeating: UInt8(i + j), count: 1024 * 256) // 256KB per segment
                buffer.addAudioData(largeData, for: sessionId, segmentIndex: j)
            }
        }
        
        let loadedStats = buffer.getMemoryStats()
        let loadedMemoryMB = loadedStats["totalMemoryUsageMB"] as? Double ?? 0
        let sessionsInMemory = loadedStats["sessionsInMemory"] as? Int ?? 0
        
        // Memory should be managed properly
        #expect(sessionsInMemory <= 10) // Respect memory limit
        #expect(loadedMemoryMB >= initialMemoryMB)
        #expect(loadedMemoryMB < 1000) // Should not exceed 1GB
        
        print("✅ Initial memory: \(String(format: "%.2f", initialMemoryMB)) MB")
        print("✅ Loaded memory: \(String(format: "%.2f", loadedMemoryMB)) MB")
        print("✅ Sessions in memory: \(sessionsInMemory)")
        
        // Clean up
        buffer.clearAllBuffers()
        
        let finalStats = buffer.getMemoryStats()
        let finalMemoryMB = finalStats["totalMemoryUsageMB"] as? Double ?? 0
        
        #expect(finalMemoryMB <= initialMemoryMB)
        
        print("✅ Final memory: \(String(format: "%.2f", finalMemoryMB)) MB")
    }
    
    @Test("Memory pressure handling performance") func testMemoryPressureHandling() async throws {
        let buffer = AudioBuffer.shared
        
        // Fill buffer with data
        for i in 0..<15 {
            let sessionId = UUID()
            buffer.createBuffer(for: sessionId)
            
            for j in 0..<20 {
                let data = Data(repeating: UInt8(i + j), count: 1024 * 128) // 128KB per segment
                buffer.addAudioData(data, for: sessionId, segmentIndex: j)
            }
        }
        
        let beforeStats = buffer.getMemoryStats()
        let beforeMemoryMB = beforeStats["totalMemoryUsageMB"] as? Double ?? 0
        let beforeSessions = beforeStats["sessionsInMemory"] as? Int ?? 0
        
        // Simulate memory pressure
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Wait for memory pressure handling
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let afterStats = buffer.getMemoryStats()
        let afterMemoryMB = afterStats["totalMemoryUsageMB"] as? Double ?? 0
        let afterSessions = afterStats["sessionsInMemory"] as? Int ?? 0
        
        // Memory should be reduced after pressure
        #expect(afterSessions <= beforeSessions)
        #expect(afterMemoryMB <= beforeMemoryMB)
        
        print("✅ Before memory pressure: \(String(format: "%.2f", beforeMemoryMB)) MB, \(beforeSessions) sessions")
        print("✅ After memory pressure: \(String(format: "%.2f", afterMemoryMB)) MB, \(afterSessions) sessions")
        
        // Clean up
        buffer.clearAllBuffers()
    }
    
    // MARK: - Processing Speed Performance Tests
    
    @Test("AudioRecorderManager segment rotation performance") func testSegmentRotationPerformance() async throws {
        let recorder = AudioRecorderManager()
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        recorder.setModelContext(modelContext)
        recorder.permissionDenied = false
        
        // Set very short segment duration for testing
        recorder.segmentDuration = 0.5 // 0.5 seconds
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Start recording
        recorder.startRecording()
        
        // Record for 10 seconds to create 20 segments
        try await Task.sleep(nanoseconds: 10_000_000_000)
        
        // Stop recording
        recorder.stopRecording()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(recorder.segments.count >= 15) // Should create at least 15 segments
        #expect(duration >= 10.0) // Should take at least 10 seconds
        #expect(duration < 15.0) // Should not take much longer than 10 seconds
        
        print("✅ Created \(recorder.segments.count) segments in \(String(format: "%.2f", duration)) seconds")
        print("✅ Average segment creation time: \(String(format: "%.3f", duration / Double(recorder.segments.count))) seconds per segment")
    }
    
    @Test("TranscriptionService batch processing performance") func testTranscriptionBatchProcessing() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create multiple test segments
        var segments: [AudioSegment] = []
        
        for i in 0..<20 {
            let segment = AudioSegment(startTime: TimeInterval(i * 30), duration: 30)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("batch_test_\(i).wav")
            segment.fileURL = tempURL
            
            // Create mock audio data
            let mockAudioData = Data(repeating: UInt8(i), count: 1024)
            try mockAudioData.write(to: tempURL)
            
            segments.append(segment)
        }
        
        // Force local transcription mode for faster processing
        TranscriptionService.shared.switchToLocalTranscription()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process all segments concurrently using a completion counter
        let totalSegments = segments.count
        var completedCount = 0
        let completionQueue = DispatchQueue(label: "completion.queue")
        
        for segment in segments {
            TranscriptionService.shared.transcribe(segment: segment, context: modelContext) { transcription in
                completionQueue.async {
                    completedCount += 1
                }
            }
        }
        
        // Wait for all transcriptions to complete (with timeout)
        let timeout = 30.0 // 30 seconds timeout
        let startWaitTime = CFAbsoluteTimeGetCurrent()
        
        while completedCount < totalSegments {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startWaitTime
            if elapsedTime > timeout {
                break // Timeout reached
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(duration < 60.0) // Should complete within 60 seconds
        
        let completedTranscriptions = segments.filter { $0.transcription != nil }.count
        print("✅ Processed \(completedTranscriptions)/\(segments.count) transcriptions in \(String(format: "%.2f", duration)) seconds")
        print("✅ Average transcription time: \(String(format: "%.2f", duration / Double(segments.count))) seconds per segment")
        
        // Clean up
        for segment in segments {
            if let url = segment.fileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    @Test("Search and filter performance with large dataset") func testSearchFilterPerformance() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create large dataset
        for i in 0..<1000 {
            let session = RecordingSession(name: "Search Test Session \(i)", date: Date(), duration: 300)
            modelContext.insert(session)
        }
        
        try modelContext.save()
        
        // Test search performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let fetchDescriptor = FetchDescriptor<RecordingSession>()
        let allSessions = try modelContext.fetch(fetchDescriptor)
        
        // Simulate search filtering
        let searchText = "Search Test"
        let filteredSessions = allSessions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(allSessions.count >= 1000)
        #expect(filteredSessions.count >= 1000) // All should match
        #expect(duration < 5.0) // Should complete within 5 seconds
        
        print("✅ Searched through \(allSessions.count) sessions in \(String(format: "%.3f", duration)) seconds")
        print("✅ Found \(filteredSessions.count) matching sessions")
    }
    
    // MARK: - UI Performance Tests
    
    @Test("Session list rendering performance") func testSessionListRenderingPerformance() async throws {
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        
        // Create test sessions with segments and transcriptions
        for i in 0..<100 {
            let session = RecordingSession(name: "UI Test Session \(i)", date: Date(), duration: 300)
            
            // Add segments with transcriptions
            for j in 0..<5 {
                let segment = AudioSegment(startTime: TimeInterval(j * 30), duration: 30)
                let transcription = Transcription(text: "Transcription \(j)", status: .completed)
                
                segment.transcription = transcription
                transcription.segment = segment
                session.segments.append(segment)
                
                modelContext.insert(segment)
                modelContext.insert(transcription)
            }
            
            modelContext.insert(session)
        }
        
        try modelContext.save()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate fetching data for UI
        let fetchDescriptor = FetchDescriptor<RecordingSession>()
        let sessions = try modelContext.fetch(fetchDescriptor)
        
        // Simulate processing for UI display
        let processedSessions = sessions.map { session in
            return (
                name: session.name,
                duration: session.duration,
                segmentCount: session.segments.count,
                completedTranscriptions: session.segments.filter { $0.transcription?.status == .completed }.count
            )
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(sessions.count >= 100)
        #expect(processedSessions.count == sessions.count)
        #expect(duration < 2.0) // Should complete within 2 seconds
        
        print("✅ Processed \(processedSessions.count) sessions for UI in \(String(format: "%.3f", duration)) seconds")
    }
    
    @Test("AudioBuffer disk operations performance") func testAudioBufferDiskOperations() async throws {
        let buffer = AudioBuffer.shared
        
        // Create test session
        let sessionId = UUID()
        buffer.createBuffer(for: sessionId)
        
        // Add data
        for i in 0..<50 {
            let audioData = Data(repeating: UInt8(i), count: 1024 * 64) // 64KB per segment
            buffer.addAudioData(audioData, for: sessionId, segmentIndex: i)
        }
        
        // Test save to disk performance
        let saveStartTime = CFAbsoluteTimeGetCurrent()
        
        var saveCompleted = false
        buffer.saveBufferToDisk(for: sessionId) { success in
            #expect(success == true)
            saveCompleted = true
        }
        
        // Wait for save to complete (with timeout)
        let saveTimeout = 10.0
        let saveStartWaitTime = CFAbsoluteTimeGetCurrent()
        
        while !saveCompleted {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let elapsedTime = CFAbsoluteTimeGetCurrent() - saveStartWaitTime
            if elapsedTime > saveTimeout {
                break // Timeout reached
            }
        }
        
        let saveEndTime = CFAbsoluteTimeGetCurrent()
        let saveDuration = saveEndTime - saveStartTime
        
        // Test load from disk performance
        let loadStartTime = CFAbsoluteTimeGetCurrent()
        
        var loadCompleted = false
        buffer.loadBufferFromDisk(for: sessionId) { success in
            #expect(success == true)
            loadCompleted = true
        }
        
        // Wait for load to complete (with timeout)
        let loadTimeout = 10.0
        let loadStartWaitTime = CFAbsoluteTimeGetCurrent()
        
        while !loadCompleted {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let elapsedTime = CFAbsoluteTimeGetCurrent() - loadStartWaitTime
            if elapsedTime > loadTimeout {
                break // Timeout reached
            }
        }
        
        let loadEndTime = CFAbsoluteTimeGetCurrent()
        let loadDuration = loadEndTime - loadStartTime
        
        #expect(saveDuration < 5.0) // Should save within 5 seconds
        #expect(loadDuration < 5.0) // Should load within 5 seconds
        
        print("✅ Save to disk: \(String(format: "%.3f", saveDuration)) seconds")
        print("✅ Load from disk: \(String(format: "%.3f", loadDuration)) seconds")
        
        // Clean up
        buffer.clearAllBuffers()
    }
} 
