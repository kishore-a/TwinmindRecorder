import Foundation
import AVFoundation
import AVFAudio

class AudioRecorderManager: NSObject, ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var recordingFormat: AVAudioFormat?
    
    @Published var isRecording = false
    @Published var error: Error?
    @Published var permissionDenied = false
    
    override init() {
        super.init()
        setupNotifications()
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
            self.beginRecording()
        }
    }
    
    private func beginRecording() {
        do {
            let format = audioEngine.inputNode.outputFormat(forBus: 0)
            self.recordingFormat = format
            let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            self.outputURL = url
            self.audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
                guard let self = self else { return }
                do {
                    try self.audioFile?.write(from: buffer)
                } catch {
                    DispatchQueue.main.async {
                        self.error = error
                        self.stopRecording()
                    }
                }
            }
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isRecording = false
            }
        }
    }
    
    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        do {
            try session.setActive(false)
        } catch {
            self.error = error
        }
        isRecording = false
    }
    
    func pauseRecording() {
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
                    beginRecording()
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
    }
} 
