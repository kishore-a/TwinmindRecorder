import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let barColor: Color
    let barWidth: CGFloat
    let spacing: CGFloat
    let maxHeight: CGFloat

    init(samples: [Float], barColor: Color = .blue, barWidth: CGFloat = 3, spacing: CGFloat = 2, maxHeight: CGFloat = 60) {
        self.samples = samples
        self.barColor = barColor
        self.barWidth = barWidth
        self.spacing = spacing
        self.maxHeight = maxHeight
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(samples.indices, id: \.self) { i in
                Capsule()
                    .fill(barColor)
                    .frame(width: barWidth, height: max(2, CGFloat(samples[i]) * maxHeight))
            }
        }
        .frame(height: maxHeight)
        .animation(.linear(duration: 0.1), value: samples)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    WaveformView(samples: Array(repeating: Float.random(in: 0...1), count: 50))
        .padding()
        .background(Color.black.opacity(0.1))
} 