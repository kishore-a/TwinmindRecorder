import Foundation
import SwiftData
import AVFoundation
import Speech

class TranscriptionService {
    // Singleton instance for easy access
    static let shared = TranscriptionService()
    private init() {}
    
    // Queue for segments that need to be transcribed when network is available
    private var offlineQueue: [AudioSegment] = []
    
    // Track consecutive failures to determine when to fallback to local transcription
    private var consecutiveFailures = 0
    private let maxFailuresBeforeFallback = 5
    private var useLocalTranscription = false
    
    // Transcribe a segment file with fallback logic
    func transcribe(segment: AudioSegment, context: ModelContext, completion: @escaping (Transcription?) -> Void) {
        // Verify the audio file exists before attempting transcription
        guard let fileURL = segment.fileURL else {
            print("⚠️ Cannot transcribe: Audio file URL is nil")
            completion(nil)
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ Cannot transcribe: Audio file not found at \(fileURL.path)")
            completion(nil)
            return
        }
        
        // Mark as processing
        let transcription = Transcription(text: "", status: TranscriptionStatus.processing)
        transcription.segment = segment
        context.insert(transcription)
        segment.transcription = transcription
        
        // Save the transcription immediately to ensure it's persisted
        do {
            try context.save()
            print("📝 Transcription started for segment: \(fileURL.lastPathComponent)")
        } catch {
            print("❌ Failed to save transcription status: \(error)")
        }
        
        // Choose transcription method based on failure count
        if useLocalTranscription {
            transcribeLocally(segment: segment) { [weak self] result in
                self?.handleTranscriptionResult(result, transcription: transcription, context: context, completion: completion)
            }
        } else {
            // Try remote API first
            sendToBackend(segment: segment) { [weak self] result in
                self?.handleTranscriptionResult(result, transcription: transcription, context: context, completion: completion)
            }
        }
    }
    
    // Handle transcription result and update failure tracking
    private func handleTranscriptionResult(_ result: Result<String, Error>, transcription: Transcription, context: ModelContext, completion: @escaping (Transcription?) -> Void) {
        switch result {
        case .success(let text):
            transcription.text = text
            transcription.status = .completed
            // Reset failure count on success
            consecutiveFailures = 0
            // Don't automatically switch back to remote - let user control this
            completion(transcription)
        case .failure(let error):
            consecutiveFailures += 1
            
            // If we've failed too many times with remote API, switch to local transcription
            if consecutiveFailures >= maxFailuresBeforeFallback && !useLocalTranscription {
                useLocalTranscription = true
                print("⚠️ Switching to local transcription after \(consecutiveFailures) consecutive failures")
                
                // Update transcription status to show it's retrying
                transcription.status = .processing
                transcription.error = "Remote transcription failed, retrying with local transcription..."
                
                // Retry with local transcription
                transcribeLocally(segment: transcription.segment!) { [weak self] localResult in
                    self?.handleTranscriptionResult(localResult, transcription: transcription, context: context, completion: completion)
                }
                return
            }
            
            // If local transcription fails, mark as failed
            if useLocalTranscription {
                transcription.status = .failed
                transcription.error = "Local transcription failed: \(error.localizedDescription)"
                completion(transcription)
            } else {
                // Remote transcription failed
                transcription.status = .failed
                transcription.error = "Remote transcription failed: \(error.localizedDescription)"
                
                // Add to offline queue for retry if it's a network error
                if isNetworkError(error) {
                    offlineQueue.append(transcription.segment!)
                }
                
                completion(transcription)
            }
        }
        // Save context after update
        try? context.save()
    }
    
    // Local transcription using Apple's Speech framework
    private func transcribeLocally(segment: AudioSegment, completion: @escaping (Result<String, Error>) -> Void) {
        guard let fileURL = segment.fileURL else {
            completion(.failure(NSError(domain: "LocalTranscription", code: 400, userInfo: [NSLocalizedDescriptionKey: "Audio file URL missing"])))
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            completion(.failure(NSError(domain: "LocalTranscription", code: 404, userInfo: [NSLocalizedDescriptionKey: "Audio file not found"])))
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.performLocalTranscription(fileURL: fileURL, completion: completion)
                case .denied:
                    completion(.failure(NSError(domain: "LocalTranscription", code: 401, userInfo: [NSLocalizedDescriptionKey: "Speech recognition access denied. Please enable in Settings."])))
                case .restricted:
                    completion(.failure(NSError(domain: "LocalTranscription", code: 403, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is restricted on this device"])))
                case .notDetermined:
                    completion(.failure(NSError(domain: "LocalTranscription", code: 404, userInfo: [NSLocalizedDescriptionKey: "Speech recognition authorization not determined"])))
                @unknown default:
                    completion(.failure(NSError(domain: "LocalTranscription", code: 405, userInfo: [NSLocalizedDescriptionKey: "Unknown speech recognition authorization status"])))
                }
            }
        }
    }
    
    private func performLocalTranscription(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            completion(.failure(NSError(domain: "LocalTranscription", code: 402, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available on this device"])))
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        
        var hasCompleted = false
        
        recognizer.recognitionTask(with: request) { result, error in
            // Prevent multiple completions
            guard !hasCompleted else { return }
            
            if let error = error {
                hasCompleted = true
                completion(.failure(error))
            } else if let result = result, result.isFinal {
                hasCompleted = true
                let transcribedText = result.bestTranscription.formattedString
                
                // Check if we got meaningful text
                if transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    completion(.failure(NSError(domain: "LocalTranscription", code: 406, userInfo: [NSLocalizedDescriptionKey: "No speech detected in audio file"])))
                } else {
                    completion(.success(transcribedText))
                }
            }
        }
    }
    
    // Prepare and send the audio file to OpenAI Whisper API
    private func sendToBackend(segment: AudioSegment, completion: @escaping (Result<String, Error>) -> Void) {
        // 1. Get the API key from Info.plist
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String else {
            completion(.failure(NSError(domain: "API", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key missing"])))
            return
        }
        // 2. Get the audio file URL
        guard let fileURL = segment.fileURL else {
            completion(.failure(NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: "Audio file URL missing"])))
            return
        }
        // 2.5. Remove resampling step; use original fileURL
        // 3. Prepare the request
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 4. Prepare multipart/form-data body
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        // Add model parameter (e.g., whisper-1)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        // Add file parameter
        if let fileData = try? Data(contentsOf: fileURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"segment.wav\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        } else {
            completion(.failure(NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to read audio file"])))
            return
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        // 5. Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network or server error
            if let error = error {
                completion(.failure(error))
                return
            }
            // Parse the response
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                let apiError = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                completion(.failure(NSError(domain: "API", code: 500, userInfo: [NSLocalizedDescriptionKey: apiError])))
                return
            }
            completion(.success(text))
        }
        task.resume()
    }
    
    // Check if error is a network error
    private func isNetworkError(_ error: Error) -> Bool {
        let networkErrorCodes = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost
        ]
        
        if let urlError = error as? URLError {
            return networkErrorCodes.contains(urlError.code.rawValue)
        }
        
        return false
    }
    
    // Reset failure tracking (useful for testing or manual override)
    func resetFailureTracking() {
        consecutiveFailures = 0
        useLocalTranscription = false
    }
    
    // Manually switch transcription mode
    func switchToLocalTranscription() {
        useLocalTranscription = true
        consecutiveFailures = 0
        print("🔄 Manually switched to local transcription")
    }
    
    func switchToRemoteTranscription() {
        useLocalTranscription = false
        consecutiveFailures = 0
        print("🔄 Manually switched to remote transcription")
    }
    
    // Get current transcription mode
    func getCurrentTranscriptionMode() -> String {
        return useLocalTranscription ? "Local (Apple Speech)" : "Remote (OpenAI Whisper)"
    }
    
    // Get detailed status information
    func getTranscriptionStatus() -> (mode: String, failureCount: Int, isFallback: Bool) {
        return (
            mode: getCurrentTranscriptionMode(),
            failureCount: consecutiveFailures,
            isFallback: useLocalTranscription && consecutiveFailures >= maxFailuresBeforeFallback
        )
    }
    
    // Retry a failed transcription
    func retryTranscription(for segment: AudioSegment, context: ModelContext, completion: @escaping (Transcription?) -> Void) {
        // Remove existing transcription if it exists
        if let existingTranscription = segment.transcription {
            context.delete(existingTranscription)
        }
        
        // Start fresh transcription
        transcribe(segment: segment, context: context, completion: completion)
    }
    
    // Process offline queue when network becomes available
    func processOfflineQueue(context: ModelContext) {
        guard !useLocalTranscription else { return }
        
        let segmentsToRetry = offlineQueue
        offlineQueue.removeAll()
        
        for segment in segmentsToRetry {
            retryTranscription(for: segment, context: context) { _ in
                // Completion handled by individual transcription
            }
        }
    }
}

// Data extension for appending to multipart/form-data
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
} 