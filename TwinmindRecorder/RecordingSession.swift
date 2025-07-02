import Foundation
import SwiftData

@Model
class RecordingSession: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var duration: TimeInterval = 0
    @Relationship(deleteRule: .cascade)
    var segments: [AudioSegment] = []
    
    init(date: Date = Date(), duration: TimeInterval = 0) {
        self.date = date
        self.duration = duration
    }
} 