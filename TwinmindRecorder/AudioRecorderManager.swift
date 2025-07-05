import Foundation
import AVFoundation
import AVFAudio
import SwiftData
import Accelerate

class AudioRecorderManager: NSObject, ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var recordingFormat: AVAudioFormat?
    private var segmentStartTime: Date?
    private var segmentTimer: Timer?
    @Published var segmentDuration: TimeInterval = 30 // Configurable segment duration in seconds
    private var currentSegmentIndex: Int = 0
    private var currentSession: RecordingSession?
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var error: Error?
    @Published var permissionDenied = false
    @Published var segments: [(url: URL, startTime: Date)] = []
    @Published var elapsedTime: TimeInterval = 0
    @Published var waveformSamples: [Float] = [] // Live waveform samples
    
    // SwiftData context for saving sessions and segments
    private var modelContext: ModelContext?
    
    private var elapsedTimer: Timer?
    private var pauseStartTime: Date?
    private var totalPausedTime: TimeInterval = 0
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    // Call this to inject the SwiftData context (e.g., from your App or View)
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    private func setupAudioSession() {
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = error
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            DispatchQueue.main.async {
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self.permissionDenied = !granted
                        completion(granted)
                    }
                }
            }
        } else {
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                    completion(granted)
                }
            }
        }
    }
    
    func startRecording() {
        requestPermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.permissionDenied = true
                self.error = NSError(domain: "Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
                return
            }
            self.setupAudioSession()
            self.segments = []
            self.currentSegmentIndex = 0
            self.elapsedTime = 0
            // Clear waveform samples for new recording
            DispatchQueue.main.async {
                self.waveformSamples.removeAll()
            }
            self.startElapsedTimer()
            // Create a new recording session in SwiftData
            let now = Date()
            let session = RecordingSession(name: nil, date: now, duration: 0)
            self.currentSession = session
            self.modelContext?.insert(session)
            // Create audio buffer for this session
            AudioBuffer.shared.createBuffer(for: session.id)
            self.beginRecordingSegment()
        }
    }
    
    private func beginRecordingSegment() {
        do {
            let format = audioEngine.inputNode.outputFormat(forBus: 0)
            self.recordingFormat = format
            let now = Date()
            self.segmentStartTime = now
            let fileName = "segment_\(now.timeIntervalSince1970)_\(currentSegmentIndex).wav"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            self.outputURL = url
            
            // Use WAV format with specific settings for best playback and Whisper compatibility
            let wavSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44100, // CD quality for playback
                AVNumberOfChannelsKey: 1, // Mono audio
                AVLinearPCMBitDepthKey: 16, // 16-bit
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            
            self.audioFile = try AVAudioFile(forWriting: url, settings: wavSettings)
            // Only install the tap and start the engine once
            if !audioEngine.isRunning {
                audioEngine.inputNode.removeTap(onBus: 0)
                // Install a tap to receive audio buffers in real time
                audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
                    guard let self = self else { return }
                    
                    // Write the audio buffer to the current file
                    if let audioFile = self.audioFile {
                        do {
                            try audioFile.write(from: buffer)
                        } catch {
                            print("⚠️ Audio write error: \(error.localizedDescription)")
                            // Don't stop recording for audio write errors, just log them
                            DispatchQueue.main.async {
                                self.error = error
                            }
                        }
                    }
                    
                    // --- Waveform calculation ---
                    if let channelData = buffer.floatChannelData?[0] {
                        let frameLength = Int(buffer.frameLength)
                        var rms: Float = 0
                        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
                        let normalized = min(max(rms * 20, 0), 1) // Normalize for UI (tweak as needed)
                        DispatchQueue.main.async {
                            self.waveformSamples.append(normalized)
                            if self.waveformSamples.count > 50 {
                                self.waveformSamples.removeFirst(self.waveformSamples.count - 50)
                            }
                        }
                    }
                    // --- End waveform calculation ---
                }
                try audioEngine.start()
            }
            DispatchQueue.main.async {
                self.isRecording = true
            }
            // Start timer for segment duration
            segmentTimer?.invalidate()
            // This timer will fire after segmentDuration seconds to rotate the segment
            segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: false) { [weak self] _ in
                self?.rotateSegment()
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isRecording = false
            }
        }
    }
    
    private func rotateSegment() {
        // Save current segment info to the published array and SwiftData
        if let url = self.outputURL, let startTime = self.segmentStartTime {
            // Ensure the audio file is properly closed before saving
            self.audioFile = nil
            
            DispatchQueue.main.async {
                self.segments.append((url: url, startTime: startTime))
            }
            
            // Calculate segment duration
            let duration = segmentDuration
            
            // Save segment to SwiftData if context and session are available
            if let context = self.modelContext, let session = self.currentSession {
                DispatchQueue.main.async {
                    // Verify the audio file exists before creating the segment
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        print("⚠️ Audio file not found at path: \(url.path)")
                        return
                    }
                    
                    let segment = AudioSegment(startTime: startTime.timeIntervalSince1970, duration: duration, fileURL: url)
                    segment.session = session
                    context.insert(segment)
                    session.segments.append(segment)
                    session.duration += duration
                    
                    // Save the context first to ensure the segment is persisted
                    do {
                        try context.save()
                        print("✅ Audio segment saved successfully: \(url.lastPathComponent)")
                    } catch {
                        print("❌ Failed to save audio segment: \(error)")
                        self.error = error
                    }
                    
                    // Add audio data to buffer
                    if let audioData = try? Data(contentsOf: url) {
                        AudioBuffer.shared.addAudioData(audioData, for: session.id, segmentIndex: self.currentSegmentIndex)
                    }
                    
                    // Trigger transcription for the new segment (this won't affect audio saving)
                    TranscriptionService.shared.transcribe(segment: segment, context: context) { transcription in
                        if let transcription = transcription {
                            print("📝 Transcription completed for segment: \(transcription.status)")
                        } else {
                            print("⚠️ Transcription failed for segment, but audio was saved")
                        }
                    }
                }
            }
        }
        
        // Prepare for the next segment
        self.outputURL = nil
        self.segmentStartTime = nil
        self.currentSegmentIndex += 1
        
        // Start new segment if still recording
        if isRecording {
            beginRecordingSegment()
        }
    }
    
    func stopRecording() {
        segmentTimer?.invalidate()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        
        do {
            try session.setActive(false)
        } catch {
            self.error = error
        }
        
        // Save last segment with proper error handling
        if let url = self.outputURL, let startTime = self.segmentStartTime {
            // Ensure the audio file is properly closed
            self.audioFile = nil
            
            self.segments.append((url: url, startTime: startTime))
            let duration = Date().timeIntervalSince(startTime)
            
            if let context = self.modelContext, let session = self.currentSession {
                DispatchQueue.main.async {
                    // Verify the audio file exists before creating the segment
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        print("⚠️ Audio file not found at path: \(url.path)")
                        return
                    }
                    
                    let segment = AudioSegment(startTime: startTime.timeIntervalSince1970, duration: duration, fileURL: url)
                    segment.session = session
                    context.insert(segment)
                    session.segments.append(segment)
                    session.duration += duration
                    
                    // Save the context first to ensure the segment is persisted
                    do {
                        try context.save()
                        print("✅ Final audio segment saved successfully: \(url.lastPathComponent)")
                    } catch {
                        print("❌ Failed to save final audio segment: \(error)")
                        self.error = error
                    }
                    
                    // Add audio data to buffer
                    if let audioData = try? Data(contentsOf: url) {
                        AudioBuffer.shared.addAudioData(audioData, for: session.id, segmentIndex: self.currentSegmentIndex)
                    }
                    
                    // Trigger transcription for the last segment (this won't affect audio saving)
                    TranscriptionService.shared.transcribe(segment: segment, context: context) { transcription in
                        if let transcription = transcription {
                            print("📝 Final transcription completed: \(transcription.status)")
                        } else {
                            print("⚠️ Final transcription failed, but audio was saved")
                        }
                    }
                }
            }
        }
        
        // Clean up
        self.outputURL = nil
        self.segmentStartTime = nil
        isRecording = false
        self.elapsedTime = 0
        
        // Clear waveform samples when stopping
        DispatchQueue.main.async {
            self.waveformSamples.removeAll()
        }
        
        // Final save to ensure everything is persisted
        if let context = self.modelContext, let _ = self.currentSession {
            do {
                try context.save()
                print("✅ Session data saved successfully")
            } catch {
                print("❌ Failed to save session data: \(error)")
            }
        }
    }
    
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        segmentTimer?.invalidate()
        audioEngine.pause()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        pauseStartTime = Date()
        isPaused = true
        
        // Clear waveform samples during pause
        DispatchQueue.main.async {
            self.waveformSamples.removeAll()
        }
    }
    
    func resumeRecording() {
        guard isPaused else { return }
        
        do {
            // Calculate total paused time
            if let pauseStart = pauseStartTime {
                totalPausedTime += Date().timeIntervalSince(pauseStart)
                pauseStartTime = nil
            }
            
            // Resume the audio engine
            try audioEngine.start()
            
            // Restart timers
            startElapsedTimer()
            
            // Restart segment timer if needed
            if let startTime = segmentStartTime {
                let elapsedInSegment = Date().timeIntervalSince(startTime) - totalPausedTime
                let remainingTime = segmentDuration - elapsedInSegment
                
                if remainingTime > 0 {
                    segmentTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                        self?.rotateSegment()
                    }
                } else {
                    // Segment should have already rotated, start new segment
                    rotateSegment()
                }
            }
            
            isPaused = false
            
        } catch {
            self.error = error
            isPaused = false
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .began {
            if isRecording { pauseRecording() }
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && !isRecording {
                    beginRecordingSegment()
                }
            }
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        if reason == .oldDeviceUnavailable {
            if isRecording { pauseRecording() }
        }
    }
    
    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording && !self.isPaused else { return }
            self.elapsedTime += 1
        }
    }
    
    // Update segment duration (can be called during recording)
    func updateSegmentDuration(_ newDuration: TimeInterval) {
        guard newDuration >= 10 && newDuration <= 300 else { return } // 10 seconds to 5 minutes
        
        segmentDuration = newDuration
        
        // If currently recording, restart the segment timer with new duration
        if isRecording && !isPaused, let startTime = segmentStartTime {
            segmentTimer?.invalidate()
            
            let elapsedInSegment = Date().timeIntervalSince(startTime) - totalPausedTime
            let remainingTime = segmentDuration - elapsedInSegment
            
            if remainingTime > 0 {
                segmentTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                    self?.rotateSegment()
                }
            } else {
                // Current segment should rotate immediately
                rotateSegment()
            }
        }
    }
    
    // Get available segment duration presets
    func getSegmentDurationPresets() -> [(String, TimeInterval)] {
        return [
            ("15 seconds", 15),
            ("30 seconds", 30),
            ("1 minute", 60),
            ("2 minutes", 120),
            ("5 minutes", 300)
        ]
    }
    
    // Ensure audio file is properly closed and saved
    private func ensureAudioFileSaved() {
        if let audioFile = self.audioFile {
            // Close the audio file to ensure it's written to disk
            self.audioFile = nil
            print("🔒 Audio file closed and saved")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        segmentTimer?.invalidate()
        ensureAudioFileSaved()
    }
} 
