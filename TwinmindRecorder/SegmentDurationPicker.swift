import SwiftUI

struct SegmentDurationPicker: View {
    @ObservedObject var recorder: AudioRecorderManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Current segment duration display
                    currentDurationCard
                    
                    // Preset buttons
                    presetButtonsSection
                    
                    // Custom duration slider
                    customDurationCard
                    
                    // Info about segmentation
                    infoCard
                    
                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.background,
                        DesignSystem.Colors.secondaryBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Segment Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var currentDurationCard: some View {
        ModernCard(shadow: DesignSystem.Shadows.medium) {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Current Duration")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Segment length setting")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                    
                    // Duration display with icon
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryGradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        VStack(spacing: 2) {
                            Text("\(Int(recorder.segmentDuration))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("sec")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
                    
    private var presetButtonsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Quick Presets")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            let gridColumns = [
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
            
            LazyVGrid(columns: gridColumns, spacing: DesignSystem.Spacing.md) {
                ForEach(recorder.getSegmentDurationPresets(), id: \.0) { preset in
                    let isSelected = recorder.segmentDuration == preset.1
                    let cardShadow = isSelected ? DesignSystem.Shadows.medium : DesignSystem.Shadows.small
                    let textColor = isSelected ? .white : DesignSystem.Colors.textPrimary
                    let secondaryTextColor = isSelected ? .white.opacity(0.9) : DesignSystem.Colors.textSecondary
                    let backgroundColor = isSelected ? DesignSystem.Colors.primaryGradient : LinearGradient(colors: [DesignSystem.Colors.tertiaryBackground, DesignSystem.Colors.tertiaryBackground], startPoint: .top, endPoint: .bottom)
                    
                    ModernCard(shadow: cardShadow) {
                        Button(action: {
                            withAnimation(Animations.spring) {
                                recorder.updateSegmentDuration(preset.1)
                            }
                        }) {
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Text(preset.0)
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(textColor)
                                Text(formatDuration(preset.1))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(backgroundColor)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .scaleEffect(isSelected ? 1.02 : 1.0)
                    .animation(Animations.spring, value: recorder.segmentDuration)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
                    
    private var customDurationCard: some View {
        ModernCard(shadow: DesignSystem.Shadows.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Custom Duration")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Set your preferred segment length")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                    
                    // Current value display
                    VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                        Text("\(Int(recorder.segmentDuration))")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("seconds")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Range labels
                    HStack {
                        Text("10s")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("5m")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    // Slider
                    Slider(
                        value: Binding(
                            get: { recorder.segmentDuration },
                            set: { recorder.updateSegmentDuration($0) }
                        ),
                        in: 10...300,
                        step: 5
                    )
                    .accentColor(DesignSystem.Colors.primary)
                    .scaleEffect(y: 1.2)
                    
                    // Step indicators
                    HStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { index in
                            Rectangle()
                                .fill(DesignSystem.Colors.primary.opacity(0.3))
                                .frame(height: 4)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.secondaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
                    
    private var infoCard: some View {
        ModernCard(shadow: DesignSystem.Shadows.small) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("About Automatic Segmentation")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    InfoRow(icon: "scissors", text: "Recordings are automatically split into segments")
                    InfoRow(icon: "text.bubble", text: "Each segment is transcribed separately")
                    InfoRow(icon: "folder", text: "Segments help with organization and playback")
                    InfoRow(icon: "slider.horizontal.3", text: "You can change duration during recording")
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
                    

    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 16)
            
            Text(text)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

#Preview {
    SegmentDurationPicker(recorder: AudioRecorderManager())
} 