import SwiftUI

struct ExpenseRowContent: View {
    let expense: Expense
    var showsReceiptIcon: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: expense.category)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(expense.category.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(expense.category.tint)

                    if showsReceiptIcon && expense.isFromReceipt {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    if !expense.memo.isEmpty {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                        Text(expense.memo)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            Text(JPYFormat.yen(expense.amount))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.title)、\(expense.category.displayName)、\(JPYFormat.yen(expense.amount))")
    }
}

/// 明細行の区切り線。最後の行には引かない。
struct ExpenseDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
            .padding(.leading, 50)
    }
}
