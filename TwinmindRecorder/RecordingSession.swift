import Foundation
import SwiftData

@Model
class RecordingSession: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var date: Date = Date()
    var duration: TimeInterval = 0
    @Relationship(deleteRule: .cascade)
    var segments: [AudioSegment] = []
    
    init(name: String? = nil, date: Date = Date(), duration: TimeInterval = 0) {
        self.date = date
        self.duration = duration
        if let name = name {
            self.name = name
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            self.name = "Session on \(formatter.string(from: date))"
        }
    }
} 