import Foundation

import AVFoundation
import SwiftUI

class AudioPlayer: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var currentSessionId: UUID?
    private var currentSegmentIndex: Int = 0
    private var allSegments: [Int: Data] = [:]
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentSegment: Int = 0
    @Published var totalSegments: Int = 0
    @Published var error: String?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            self.error = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    // Load a session for playback
    func loadSession(_ sessionId: UUID, completion: @escaping (Bool) -> Void) {
        let segments = AudioBuffer.shared.getAllSegments(for: sessionId)
        
        DispatchQueue.main.async {
            self.currentSessionId = sessionId
            self.allSegments = segments
            self.totalSegments = segments.count
            self.currentSegment = 0
            self.currentTime = 0
            self.duration = 0
            self.isPlaying = false
            
            if !segments.isEmpty {
                completion(true)
            } else {
                self.error = "No audio segments found for this session"
                completion(false)
            }
        }
    }
    
    // Play a specific segment
    func playSegment(_ segmentIndex: Int) {
        guard let currentSessionId = currentSessionId,
              let audioData = allSegments[segmentIndex] else {
            error = "Audio data not found for segment \(segmentIndex)"
            return
        }
        
        do {
            // Stop current playback
            stop()
            
            // Create audio player from data
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            currentSegment = segmentIndex
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            
            // Start playback
            audioPlayer?.play()
            isPlaying = true
            error = nil
            
            // Start timer for progress updates
            startProgressTimer()
            
        } catch {
            self.error = "Failed to play audio: \(error.localizedDescription)"
        }
    }
    
    // Play the current session from the beginning
    func playSession() {
        if allSegments.isEmpty {
            error = "No audio segments available"
            return
        }
        
        let firstSegmentIndex = allSegments.keys.sorted().first ?? 0
        playSegment(firstSegmentIndex)
    }
    
    // Play next segment
    func playNextSegment() {
        let sortedIndices = allSegments.keys.sorted()
        if let currentIndex = sortedIndices.firstIndex(of: currentSegment),
           currentIndex + 1 < sortedIndices.count {
            playSegment(sortedIndices[currentIndex + 1])
        } else {
            stop()
        }
    }
    
    // Play previous segment
    func playPreviousSegment() {
        let sortedIndices = allSegments.keys.sorted()
        if let currentIndex = sortedIndices.firstIndex(of: currentSegment),
           currentIndex > 0 {
            playSegment(sortedIndices[currentIndex - 1])
        }
    }
    
    // Play current segment
    func play() {
        if audioPlayer == nil && !allSegments.isEmpty {
            playSegment(currentSegment)
        } else {
            audioPlayer?.play()
            isPlaying = true
            startProgressTimer()
        }
    }
    
    // Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }
    
    // Stop playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
    }
    
    // Seek to specific time in current segment
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    // Seek to specific segment
    func seekToSegment(_ segmentIndex: Int) {
        if allSegments.keys.contains(segmentIndex) {
            playSegment(segmentIndex)
        }
    }
    
    // Get formatted time string
    func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Get current segment info
    func getCurrentSegmentInfo() -> (index: Int, time: String, duration: String)? {
        guard audioPlayer != nil else { return nil }
        return (
            index: currentSegment,
            time: formattedTime(currentTime),
            duration: formattedTime(duration)
        )
    }
    
    // Get all segment indices sorted
    func getSegmentIndices() -> [Int] {
        return allSegments.keys.sorted()
    }
    
    // Check if segment exists
    func hasSegment(_ index: Int) -> Bool {
        return allSegments.keys.contains(index)
    }
    
    // Get segment duration (estimated)
    func getSegmentDuration(_ index: Int) -> TimeInterval {
        // This is an estimation based on typical audio settings
        // For more accurate duration, you'd need to decode the audio file
        guard let data = allSegments[index] else { return 0 }
        
        // Estimate based on WAV format: 16kHz, 16-bit, mono
        let bytesPerSecond = 16000 * 2 // 16-bit = 2 bytes per sample
        return Double(data.count) / Double(bytesPerSecond)
    }
    
    // MARK: - Private Methods
    
    private var progressTimer: Timer?
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.stopProgressTimer()
            
            if flag {
                // Auto-play next segment if available
                self.playNextSegment()
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.stopProgressTimer()
            self.error = "Audio playback error: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
} 
