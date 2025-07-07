//
//  TwinmindRecorderTests.swift
//  TwinmindRecorderTests
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import Testing
import Foundation
import SwiftData
@testable import TwinmindRecorder

struct TwinmindRecorderTests {
    
    // MARK: - Test Suite Organization
    
    // Unit Tests - Core business logic and data models
    @Test("Unit Tests Suite") func unitTestsSuite() async throws {
        let unitTests = UnitTests()
        
        // Data Model Tests
        try  unitTests.testRecordingSessionInitialization()
        try  unitTests.testRecordingSessionDefaultName()
        try  unitTests.testAudioSegmentInitialization()
        try  unitTests.testTranscriptionInitialization()
        try  unitTests.testTranscriptionStatusTransitions()
        
        // AudioBuffer Tests
        try  unitTests.testAudioBufferSingleton()
        try  unitTests.testAudioBufferSessionManagement()
        try  unitTests.testAudioBufferMemoryManagement()
        try  unitTests.testAudioBufferSegmentManagement()
        
        // Business Logic Tests
        try  unitTests.testSessionDurationCalculation()
        try  unitTests.testTranscriptionCompletionRate()
        try  unitTests.testDateGroupingLogic()
        try  unitTests.testSearchAndFilterLogic()
        
        // Error Handling Tests
        try  unitTests.testInvalidAudioSegmentHandling()
        try  unitTests.testEmptyTranscriptionHandling()
        try  unitTests.testAudioBufferErrorHandling()
    }
    
    // Integration Tests - Audio system and API integration
    @Test("Integration Tests Suite") func integrationTestsSuite() async throws {
        let integrationTests = IntegrationTests()
        
        // Audio System Integration Tests
        try await integrationTests.testAudioRecorderAndBufferIntegration()
        try await integrationTests.testSegmentRotationIntegration()
        try await integrationTests.testTranscriptionServiceIntegration()
        try await integrationTests.testAudioPlayerIntegration()
        try await integrationTests.testSwiftDataPersistence()
        
        // API Integration Tests
        try await integrationTests.testTranscriptionServiceFallback()
        try await integrationTests.testOfflineQueueProcessing()
        try await integrationTests.testPauseResumeIntegration()
        try await integrationTests.testInterruptionHandling()
        try await integrationTests.testMemoryManagementIntegration()
    }
    
    // Edge Case Tests - Error scenarios and recovery
    @Test("Edge Case Tests Suite") func edgeCaseTestsSuite() async throws {
        let edgeCaseTests = EdgeCaseTests()
        
        // Permission and Authorization Edge Cases
        try await edgeCaseTests.testPermissionDeniedHandling()
        try await edgeCaseTests.testSpeechRecognitionAuthorizationDenied()
        
        // File System Edge Cases
        try await edgeCaseTests.testMissingAudioFileHandling()
        try await edgeCaseTests.testAudioBufferDiskSpaceHandling()
        try await edgeCaseTests.testCorruptedAudioFile()
        
        // Network and API Edge Cases
        try await edgeCaseTests.testNetworkTimeoutHandling()
        try await edgeCaseTests.testConsecutiveFailuresHandling()
        
        // Memory and Performance Edge Cases
        try await edgeCaseTests.testMemoryPressureHandling()
        try await edgeCaseTests.testExtremeMemoryUsage()
        
        // Audio Session Edge Cases
        try await edgeCaseTests.testAudioSessionConfigurationFailure()
        try await edgeCaseTests.testRouteChangeHandling()
        
        // Data Model Edge Cases
        try await edgeCaseTests.testSwiftDataConcurrentAccess()
        try await edgeCaseTests.testAudioSegmentInvalidTimeValues()
        try await edgeCaseTests.testRecordingSessionEdgeCaseNames()
        
        // Recovery Scenarios
        try await edgeCaseTests.testRecoveryAfterInterruption()
        try await edgeCaseTests.testTranscriptionServiceRecovery()
    }
    
    // Performance Tests - Large datasets and processing speed
    @Test("Performance Tests Suite") func performanceTestsSuite() async throws {
        let performanceTests = PerformanceTests()
        
        // Large Dataset Performance Tests
        try await performanceTests.testLargeDatasetInsertion()
        try await performanceTests.testLargeDatasetQueryPerformance()
        try await performanceTests.testAudioBufferLargeDataset()
        try await performanceTests.testAudioBufferRetrievalPerformance()
        
        // Memory Usage Performance Tests
        try await performanceTests.testMemoryUsageUnderLoad()
        try await performanceTests.testMemoryPressureHandling()
        
        // Processing Speed Performance Tests
        try await performanceTests.testSegmentRotationPerformance()
        try await performanceTests.testTranscriptionBatchProcessing()
        try await performanceTests.testSearchFilterPerformance()
        
        // UI Performance Tests
        try await performanceTests.testSessionListRenderingPerformance()
        try await performanceTests.testAudioBufferDiskOperations()
    }
    
    // MARK: - Quick Smoke Tests
    
    @Test("Quick Smoke Test") func quickSmokeTest() async throws {
        // Basic functionality test
        let session = RecordingSession(name: "Smoke Test", date: Date(), duration: 30)
        #expect(session.name == "Smoke Test")
        #expect(session.segments.isEmpty)
        
        // AudioBuffer basic test
        let buffer = AudioBuffer.shared
        let sessionId = UUID()
        buffer.createBuffer(for: sessionId)
        #expect(buffer.getMemoryStats()["sessionsInMemory"] as? Int ?? 0 > 0)
        
        // Clean up
        buffer.clearAllBuffers()
    }
    
    // MARK: - Test Utilities
    
    @Test("Test Environment Setup") func testEnvironmentSetup() async throws {
        // Verify test environment is properly configured
        #expect(true) // Basic assertion to ensure tests can run
        
        // Check that we can create SwiftData containers
        let modelContext = try await ModelContainer(for: RecordingSession.self, AudioSegment.self, Transcription.self).mainContext
        #expect(modelContext != nil)
        
        // Check that we can access the main app components
        let buffer = AudioBuffer.shared
        #expect(buffer != nil)
        
        let transcriptionService = TranscriptionService.shared
        #expect(transcriptionService != nil)
    }
}
