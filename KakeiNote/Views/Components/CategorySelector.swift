import SwiftUI

struct CategorySelector: View {
    @Binding var selection: ExpenseCategory
    var columns: Int = 5

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(ExpenseCategory.allCases) { category in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selection = category
                    }
                    Haptics.selection()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: category.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                        Text(category.displayName)
                            .font(.system(size: 9.5, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selection == category ? Color.white : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(selection == category ? category.tint.opacity(0.82) : Theme.surfaceHigh)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(selection == category ? category.tint.opacity(0.9) : Theme.stroke, lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(category.displayName)
                .accessibilityAddTraits(selection == category ? [.isSelected] : [])
            }
        }
    }
}

enum Haptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
