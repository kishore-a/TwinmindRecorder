import Foundation
import AVFoundation

class AudioBuffer: ObservableObject {
    static let shared = AudioBuffer()
    private init() {}
    
    // Buffer storage for each session
    private var sessionBuffers: [UUID: SessionAudioBuffer] = [:]
    private let bufferQueue = DispatchQueue(label: "com.twinmind.audiobuffer", qos: .userInitiated)
    
    // Maximum buffer size per session (in MB)
    private let maxBufferSizeMB: Int = 100
    
    // Create a new buffer for a session
    func createBuffer(for sessionId: UUID) {
        bufferQueue.async {
            self.sessionBuffers[sessionId] = SessionAudioBuffer(sessionId: sessionId)
        }
    }
    
    // Add audio data to a session's buffer
    func addAudioData(_ data: Data, for sessionId: UUID, segmentIndex: Int) {
        bufferQueue.async {
            guard var sessionBuffer = self.sessionBuffers[sessionId] else {
                print("⚠️ No buffer found for session: \(sessionId)")
                return
            }
            
            sessionBuffer.addSegment(data: data, index: segmentIndex)
            self.sessionBuffers[sessionId] = sessionBuffer
            
            // Check if buffer size exceeds limit
            if sessionBuffer.totalSize > self.maxBufferSizeMB * 1024 * 1024 {
                self.cleanupOldSegments(for: sessionId)
            }
        }
    }
    
    // Get audio data for a specific segment
    func getAudioData(for sessionId: UUID, segmentIndex: Int) -> Data? {
        var result: Data?
        let semaphore = DispatchSemaphore(value: 0)
        
        bufferQueue.async {
            if let sessionBuffer = self.sessionBuffers[sessionId] {
                result = sessionBuffer.getSegment(index: segmentIndex)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    // Get all segments for a session
    func getAllSegments(for sessionId: UUID) -> [Int: Data] {
        var result: [Int: Data] = [:]
        let semaphore = DispatchSemaphore(value: 0)
        
        bufferQueue.async {
            if let sessionBuffer = self.sessionBuffers[sessionId] {
                result = sessionBuffer.getAllSegments()
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    // Save buffer to disk for a session
    func saveBufferToDisk(for sessionId: UUID, completion: @escaping (Bool) -> Void) {
        bufferQueue.async {
            guard let sessionBuffer = self.sessionBuffers[sessionId] else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            let success = sessionBuffer.saveToDisk()
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    // Load buffer from disk for a session
    func loadBufferFromDisk(for sessionId: UUID, completion: @escaping (Bool) -> Void) {
        bufferQueue.async {
            var sessionBuffer = SessionAudioBuffer(sessionId: sessionId)
            let success = sessionBuffer.loadFromDisk()
            
            if success {
                self.sessionBuffers[sessionId] = sessionBuffer
            }
            
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    // Clean up old segments to manage memory
    private func cleanupOldSegments(for sessionId: UUID) {
        guard var sessionBuffer = sessionBuffers[sessionId] else { return }
        
        // Keep only the most recent segments
        let maxSegments = 50 // Keep last 50 segments
        sessionBuffer.cleanupOldSegments(keeping: maxSegments)
        sessionBuffers[sessionId] = sessionBuffer
        
        print("🧹 Cleaned up old segments for session: \(sessionId)")
    }
    
    // Remove buffer for a session
    func removeBuffer(for sessionId: UUID) {
        bufferQueue.async {
            self.sessionBuffers.removeValue(forKey: sessionId)
            print("🗑️ Removed buffer for session: \(sessionId)")
        }
    }
    
    // Get buffer statistics
    func getBufferStats(for sessionId: UUID) -> BufferStats? {
        var result: BufferStats?
        let semaphore = DispatchSemaphore(value: 0)
        
        bufferQueue.async {
            if let sessionBuffer = self.sessionBuffers[sessionId] {
                result = sessionBuffer.getStats()
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    // Clear all buffers (for memory management)
    func clearAllBuffers() {
        bufferQueue.async {
            self.sessionBuffers.removeAll()
            print("🧹 Cleared all audio buffers")
        }
    }
}

// Individual session buffer
struct SessionAudioBuffer {
    let sessionId: UUID
    private var segments: [Int: Data] = [:]
    private var segmentSizes: [Int: Int] = [:]
    
    // Make initializer public
    init(sessionId: UUID) {
        self.sessionId = sessionId
    }
    
    var totalSize: Int {
        return segmentSizes.values.reduce(0, +)
    }
    
    mutating func addSegment(data: Data, index: Int) {
        segments[index] = data
        segmentSizes[index] = data.count
    }
    
    func getSegment(index: Int) -> Data? {
        return segments[index]
    }
    
    func getAllSegments() -> [Int: Data] {
        return segments
    }
    
    mutating func cleanupOldSegments(keeping count: Int) {
        let sortedIndices = segments.keys.sorted()
        let indicesToRemove = sortedIndices.dropLast(count)
        
        for index in indicesToRemove {
            segments.removeValue(forKey: index)
            segmentSizes.removeValue(forKey: index)
        }
    }
    
    func getStats() -> BufferStats {
        return BufferStats(
            sessionId: sessionId,
            segmentCount: segments.count,
            totalSize: totalSize,
            averageSegmentSize: segments.isEmpty ? 0 : totalSize / segments.count
        )
    }
    
    // Save buffer to disk
    func saveToDisk() -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bufferDirectory = documentsPath.appendingPathComponent("AudioBuffers")
        let sessionDirectory = bufferDirectory.appendingPathComponent(sessionId.uuidString)
        
        do {
            // Create directories if they don't exist
            try FileManager.default.createDirectory(at: bufferDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
            
            // Save segments
            for (index, data) in segments {
                let segmentFile = sessionDirectory.appendingPathComponent("segment_\(index).wav")
                try data.write(to: segmentFile)
            }
            
            // Save metadata
            let metadata = BufferMetadata(
                sessionId: sessionId,
                segmentCount: segments.count,
                totalSize: totalSize,
                segmentIndices: Array(segments.keys)
            )
            
            let metadataFile = sessionDirectory.appendingPathComponent("metadata.json")
            let metadataData = try JSONEncoder().encode(metadata)
            try metadataData.write(to: metadataFile)
            
            print("💾 Saved buffer to disk for session: \(sessionId)")
            return true
        } catch {
            print("❌ Failed to save buffer to disk: \(error)")
            return false
        }
    }
    
    // Load buffer from disk
    mutating func loadFromDisk() -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bufferDirectory = documentsPath.appendingPathComponent("AudioBuffers")
        let sessionDirectory = bufferDirectory.appendingPathComponent(sessionId.uuidString)
        
        do {
            // Load metadata
            let metadataFile = sessionDirectory.appendingPathComponent("metadata.json")
            let metadataData = try Data(contentsOf: metadataFile)
            let metadata = try JSONDecoder().decode(BufferMetadata.self, from: metadataData)
            
            // Load segments
            for index in metadata.segmentIndices {
                let segmentFile = sessionDirectory.appendingPathComponent("segment_\(index).wav")
                let data = try Data(contentsOf: segmentFile)
                segments[index] = data
                segmentSizes[index] = data.count
            }
            
            print("📂 Loaded buffer from disk for session: \(sessionId)")
            return true
        } catch {
            print("❌ Failed to load buffer from disk: \(error)")
            return false
        }
    }
}

// Buffer statistics
struct BufferStats {
    let sessionId: UUID
    let segmentCount: Int
    let totalSize: Int
    let averageSegmentSize: Int
    
    var totalSizeMB: Double {
        return Double(totalSize) / (1024 * 1024)
    }
    
    var averageSegmentSizeKB: Double {
        return Double(averageSegmentSize) / 1024
    }
}

// Buffer metadata for disk storage
struct BufferMetadata: Codable {
    let sessionId: UUID
    let segmentCount: Int
    let totalSize: Int
    let segmentIndices: [Int]
} 