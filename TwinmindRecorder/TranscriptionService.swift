import Foundation
import SwiftData

class TranscriptionService {
    // Singleton instance for easy access
    static let shared = TranscriptionService()
    private init() {}
    
    // Queue for segments that need to be transcribed when network is available
    private var offlineQueue: [AudioSegment] = []
    
    // Transcribe a segment file using a backend API
    func transcribe(segment: AudioSegment, context: ModelContext, completion: @escaping (Transcription?) -> Void) {
        // Mark as processing
        let transcription = Transcription(text: "", status: TranscriptionStatus.processing)
        transcription.segment = segment
        context.insert(transcription)
        segment.transcription = transcription
        
        // Call the real API
        sendToBackend(segment: segment) { [weak self] result in
            switch result {
            case .success(let text):
                transcription.text = text
                transcription.status = .completed
                completion(transcription)
            case .failure(let error):
                transcription.status = .failed
                transcription.error = error.localizedDescription
                // Add to offline queue for retry if network error
                if self?.isNetworkError(error) == true {
                    self?.offlineQueue.append(segment)
                }
                completion(transcription)
            }
            // Save context after update
            try? context.save()
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
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"segment.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
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
    
    // Retry logic and offline queue processing would go here
}

// Data extension for appending to multipart/form-data
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
} 