import Foundation
import AVFoundation
import AVFAudio
import SwiftData

class AudioRecorderManager: NSObject, ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var recordingFormat: AVAudioFormat?
    private var segmentStartTime: Date?
    private var segmentTimer: Timer?
    private let segmentDuration: TimeInterval = 30 // seconds, configurable
    private var currentSegmentIndex: Int = 0
    private var currentSession: RecordingSession?
    
    @Published var isRecording = false
    @Published var error: Error?
    @Published var permissionDenied = false
    @Published var segments: [(url: URL, startTime: Date)] = []
    
    // SwiftData context for saving sessions and segments
    private var modelContext: ModelContext?
    
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
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                    completion(granted)
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
            // Create a new recording session in SwiftData
            let session = RecordingSession(date: Date(), duration: 0)
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
            
            // Use WAV format with specific settings for better compatibility
            let wavSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000, // Whisper prefers 16kHz
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
                    do {
                        // Write the audio buffer to the current file
                        try self.audioFile?.write(from: buffer)
                    } catch {
                        DispatchQueue.main.async {
                            self.error = error
                            self.stopRecording()
                        }
                    }
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
            DispatchQueue.main.async {
                self.segments.append((url: url, startTime: startTime))
            }
            // Calculate segment duration
            let duration = segmentDuration
            // Save segment to SwiftData if context and session are available
            if let context = self.modelContext, let session = self.currentSession {
                DispatchQueue.main.async {
                    let segment = AudioSegment(startTime: startTime.timeIntervalSince1970, duration: duration, fileURL: url)
                    segment.session = session
                    context.insert(segment)
                    session.segments.append(segment)
                    session.duration += duration
                    try? context.save()
                    
                    // Add audio data to buffer
                    if let audioData = try? Data(contentsOf: url) {
                        AudioBuffer.shared.addAudioData(audioData, for: session.id, segmentIndex: self.currentSegmentIndex)
                    }
                    
                    // Trigger transcription for the new segment
                    TranscriptionService.shared.transcribe(segment: segment, context: context) { _ in
                        // Optionally handle completion or update UI
                    }
                }
            }
        }
        // Close current file and prepare for the next segment
        self.audioFile = nil
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
        do {
            try session.setActive(false)
        } catch {
            self.error = error
        }
        // Save last segment
        if let url = self.outputURL, let startTime = self.segmentStartTime {
            self.segments.append((url: url, startTime: startTime))
            let duration = Date().timeIntervalSince(startTime)
            if let context = self.modelContext, let session = self.currentSession {
                DispatchQueue.main.async {
                    let segment = AudioSegment(startTime: startTime.timeIntervalSince1970, duration: duration, fileURL: url)
                    segment.session = session
                    context.insert(segment)
                    session.segments.append(segment)
                    session.duration += duration
                    try? context.save()
                    
                    // Add audio data to buffer
                    if let audioData = try? Data(contentsOf: url) {
                        AudioBuffer.shared.addAudioData(audioData, for: session.id, segmentIndex: self.currentSegmentIndex)
                    }
                    
                    // Trigger transcription for the last segment
                    TranscriptionService.shared.transcribe(segment: segment, context: context) { _ in
                        // Optionally handle completion or update UI
                    }
                }
            }
        }
        self.audioFile = nil
        self.outputURL = nil
        self.segmentStartTime = nil
        isRecording = false
        // Optionally, update the session's total duration in SwiftData
        if let context = self.modelContext, let _ = self.currentSession {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    func pauseRecording() {
        segmentTimer?.invalidate()
        audioEngine.pause()
        isRecording = false
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        segmentTimer?.invalidate()
    }
} 
