import Foundation
import SwiftData

enum TranscriptionStatus: String, Codable {
    case pending, processing, completed, failed
}

@Model
class Transcription: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var text: String = ""
    var status: TranscriptionStatus = TranscriptionStatus.pending
    var error: String?
    var segment: AudioSegment?
    
    init(text: String = "", status: TranscriptionStatus = TranscriptionStatus.pending, error: String? = nil) {
        self.text = text
        self.status = status
        self.error = error
    }
} 