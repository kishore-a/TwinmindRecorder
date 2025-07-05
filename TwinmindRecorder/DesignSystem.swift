import SwiftUI

// MARK: - Design System
struct DesignSystem {
    // MARK: - Colors
    struct Colors {
        static let primary = Color.blue
        static let primaryGradient = LinearGradient(
            colors: [Color.blue, Color.blue.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let secondary = Color.orange
        static let secondaryGradient = LinearGradient(
            colors: [Color.orange, Color.orange.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        
        static let cardBackground = Color(.systemBackground)
        static let cardShadow = Color.black.opacity(0.1)
        
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        
        // Recording-specific colors
        static let recording = Color.red
        static let recordingGradient = LinearGradient(
            colors: [Color.red, Color.red.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let paused = Color.orange
        static let stopped = Color.gray
        
        // Waveform colors
        static let waveformActive = Color.blue
        static let waveformInactive = Color.gray.opacity(0.3)
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        static let headline = Font.headline.weight(.semibold)
        static let subheadline = Font.subheadline.weight(.medium)
        static let body = Font.body
        static let callout = Font.callout
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 50
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Reusable UI Components
struct ModernCard<Content: View>: View {
    let content: Content
    let shadow: DesignSystem.Shadow
    
    init(shadow: DesignSystem.Shadow = DesignSystem.Shadows.small, @ViewBuilder content: () -> Content) {
        self.shadow = shadow
        self.content = content()
    }
    
    var body: some View {
        content
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

struct GradientButton<Content: View>: View {
    let action: () -> Void
    let content: Content
    let gradient: LinearGradient
    let isEnabled: Bool
    
    init(
        gradient: LinearGradient = DesignSystem.Colors.primaryGradient,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.isEnabled = isEnabled
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(gradient)
                        .opacity(isEnabled ? 1.0 : 0.5)
                )
        }
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.1), value: isEnabled)
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void
    let color: Color
    let size: CGFloat
    let isEnabled: Bool
    
    init(
        icon: String,
        color: Color = DesignSystem.Colors.primary,
        size: CGFloat = 24,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.size = size
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(color.opacity(isEnabled ? 1.0 : 0.5))
                .frame(width: size + 16, height: size + 16)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                        .opacity(isEnabled ? 1.0 : 0.5)
                )
        }
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1.0 : 0.9)
        .animation(.easeInOut(duration: 0.1), value: isEnabled)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(DesignSystem.Typography.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    
    init(progress: Double, color: Color = DesignSystem.Colors.primary, size: CGFloat = 60, lineWidth: CGFloat = 4) {
        self.progress = progress
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Animations
struct Animations {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    static let easeInOut = Animation.easeInOut(duration: 0.3)
    static let easeOut = Animation.easeOut(duration: 0.2)
    static let linear = Animation.linear(duration: 0.1)
}

// MARK: - Extensions
extension View {
    func modernCard(shadow: DesignSystem.Shadow = DesignSystem.Shadows.small) -> some View {
        self.background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func glassmorphism() -> some View {
        self.background(.ultraThinMaterial)
            .cornerRadius(DesignSystem.CornerRadius.md)
    }
} 