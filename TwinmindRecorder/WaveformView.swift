import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let barColor: Color
    let barWidth: CGFloat
    let spacing: CGFloat
    let maxHeight: CGFloat

    init(samples: [Float], barColor: Color = DesignSystem.Colors.waveformActive, barWidth: CGFloat = 3, spacing: CGFloat = 2, maxHeight: CGFloat = 60) {
        self.samples = samples
        self.barColor = barColor
        self.barWidth = barWidth
        self.spacing = spacing
        self.maxHeight = maxHeight
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(displayedSamples.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    barColor,
                                    barColor.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: max(2, CGFloat(displayedSamples[i]) * maxHeight))
                        .shadow(color: barColor.opacity(0.3), radius: 1, x: 0, y: 1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: maxHeight)
            .animation(Animations.linear, value: displayedSamples)
        }
        .frame(height: maxHeight)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    // Calculate how many samples to display based on available width
    private var displayedSamples: [Float] {
        let maxSamples = 50 // Limit to prevent layout issues
        if samples.count <= maxSamples {
            return samples
        } else {
            // Take the most recent samples and downsample if needed
            let recentSamples = Array(samples.suffix(maxSamples))
            return recentSamples
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spacing.lg) {
        WaveformView(samples: Array(repeating: Float.random(in: 0...1), count: 50))
            .modernCard()
            .padding()
        
        WaveformView(
            samples: Array(repeating: Float.random(in: 0...1), count: 30),
            barColor: DesignSystem.Colors.recording,
            barWidth: 4,
            spacing: 3,
            maxHeight: 80
        )
        .modernCard()
        .padding()
    }
    .background(DesignSystem.Colors.secondaryBackground)
} 