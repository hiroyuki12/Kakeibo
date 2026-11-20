import SwiftUI

enum Theme {
    static let background = Color(hex: 0x0A0C0F)
    static let backgroundElevated = Color(hex: 0x101318)
    static let surface = Color(hex: 0x151A20)
    static let surfaceHigh = Color(hex: 0x1D232C)
    static let surfaceHover = Color(hex: 0x252C37)
    static let stroke = Color.white.opacity(0.07)
    static let strokeStrong = Color.white.opacity(0.14)

    static let accent = Color(hex: 0x4C8DFF)
    static let accentDeep = Color(hex: 0x2E6FE0)
    static let accentSoft = Color(hex: 0x4C8DFF).opacity(0.14)

    static let textPrimary = Color(hex: 0xF3F5F8)
    static let textSecondary = Color(hex: 0x9BA4B3)
    static let textTertiary = Color(hex: 0x697383)

    static let warning = Color(hex: 0xF5A524)
    static let danger = Color(hex: 0xF15454)
    static let success = Color(hex: 0x35D08A)

    static let sunday = Color(hex: 0xFF7A7A)
    static let saturday = Color(hex: 0x7C9CFF)
    static let cardRadius: CGFloat = 20
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension ExpenseCategory {
    var tint: Color {
        switch self {
        case .food: return Color(hex: 0x38C976)
        case .dailyGoods: return Color(hex: 0x2EC5D9)
        case .dining: return Color(hex: 0xFF9F45)
        case .transport: return Color(hex: 0x5B95FF)
        case .medical: return Color(hex: 0xFF7272)
        case .clothing: return Color(hex: 0xB583FF)
        case .entertainment: return Color(hex: 0xFF7DB5)
        case .utilities: return Color(hex: 0xF7C948)
        case .communication: return Color(hex: 0x7D8DFF)
        case .other: return Color(hex: 0x8D98A8)
        }
    }
}

// MARK: - 再利用可能な修飾子

struct SurfaceCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var fill: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func surfaceCard(
        padding: CGFloat = 18,
        radius: CGFloat = Theme.cardRadius,
        fill: Color = Theme.surface
    ) -> some View {
        modifier(SurfaceCardModifier(padding: padding, radius: radius, fill: fill))
    }

    /// 画面全体の背景。
    func appBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.975

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 共通パーツ

struct SectionLabel: View {
    let text: String
    var optional: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            if optional {
                Text("任意")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.surfaceHigh))
            }
        }
    }
}

struct PrimaryActionButton: View {
    let title: String
    var symbol: String? = nil
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Theme.accent.opacity(isEnabled ? 0.28 : 0), radius: 16, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

struct CategoryIcon: View {
    let category: ExpenseCategory
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(category.tint.opacity(0.15))
            Image(systemName: category.symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(category.tint)
        }
        .frame(width: size, height: size)
    }
}

struct PillLabel: View {
    let text: String
    var color: Color = Theme.textSecondary
    var background: Color = Theme.surfaceHigh

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(background))
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct KeyboardDoneToolbar: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let action: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    action()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

extension View {
    func keyboardDone(action: @escaping () -> Void) -> some View {
        modifier(KeyboardDoneToolbar(action: action))
    }
}

/// 数字だけを保持し、表示時に3桁区切りへ整形する金額入力。
struct AmountTextField: View {
    @Binding var text: String
    var placeholder: String = "0"
    var fontSize: CGFloat = 42
    var alignment: TextAlignment = .leading
    var accessibilityID: String? = nil

    var body: some View {
        TextField(placeholder, text: Binding(
            get: { text },
            set: { newValue in
                text = JPYFormat.formattedInput(newValue)
            }
        ))
        .keyboardType(.numberPad)
        .font(.system(size: fontSize, weight: .bold, design: .rounded))
        .foregroundStyle(Theme.textPrimary)
        .multilineTextAlignment(alignment)
        .monospacedDigit()
        .accessibilityIdentifier(accessibilityID ?? "")
    }
}
