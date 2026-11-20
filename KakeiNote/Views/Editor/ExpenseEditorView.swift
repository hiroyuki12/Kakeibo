import SwiftUI
import UIKit

/// 追加・編集の両方で使う支出フォーム。シートとして表示する。
struct ExpenseEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let expense: Expense?
    let defaultDate: Date

    @State private var title: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var memo: String
    @State private var showDeleteConfirm = false
    @State private var showReceiptPreview = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case amount
        case memo
    }

    init(expense: Expense?, defaultDate: Date) {
        self.expense = expense
        self.defaultDate = defaultDate
        _title = State(initialValue: expense?.title ?? "")
        _amountText = State(initialValue: expense.map { JPYFormat.grouped(String($0.amount)) } ?? "")
        _category = State(initialValue: expense?.category ?? .food)
        _date = State(initialValue: expense?.date ?? KakeiCalendar.startOfDay(defaultDate))
        _memo = State(initialValue: expense?.memo ?? "")
    }

    private var isEditing: Bool { expense != nil }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && JPYFormat.amount(from: amountText) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        amountCard
                        titleCard
                        categoryCard
                        detailsCard
                        receiptCard
                        deleteSection
                        metadataFooter
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    saveBar
                }
            }
            .navigationTitle(isEditing ? "支出を編集" : "支出を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .sheet(isPresented: $showReceiptPreview) {
                if let image = receiptImage {
                    ReceiptImageViewer(image: image, title: "レシート画像")
                }
            }
            .alert("この支出を削除しますか？", isPresented: $showDeleteConfirm) {
                Button("削除", role: .destructive) {
                    if let expense {
                        model.deleteExpense(expense)
                        Haptics.success()
                        dismiss()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("削除すると元に戻せません。")
            }
            .keyboardDone {
                focusedField = nil
            }
        }
    }

    private var receiptImage: UIImage? {
        model.receiptImage(named: expense?.receiptImageName)
    }

    // MARK: - 金額

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(text: "金額")
                Spacer()
                Text("円")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("¥")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                AmountTextField(
                    text: $amountText,
                    fontSize: 44,
                    accessibilityID: "editor.amountField"
                )
                .focused($focusedField, equals: .amount)
                .frame(minHeight: 52)
            }
        }
        .surfaceCard(padding: 16)
    }

    // MARK: - 項目名

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "項目名")

            HStack(spacing: 8) {
                TextField("例：スーパーでの買い物", text: $title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .accessibilityIdentifier("editor.titleField")

                if !title.isEmpty {
                    Button {
                        title = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .surfaceCard(padding: 16)
    }

    // MARK: - カテゴリ

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "カテゴリ")
            CategorySelector(selection: $category)
        }
        .surfaceCard(padding: 14)
    }

    // MARK: - 日付・メモ

    private var detailsCard: some View {
        VStack(spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("日付")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .tint(Theme.accent)
            }

            Divider().overlay(Theme.stroke)

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "メモ", optional: true)
                TextField("お店の名前など（任意）", text: $memo, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .memo)
            }
        }
        .surfaceCard(padding: 16)
    }

    // MARK: - レシート

    @ViewBuilder
    private var receiptCard: some View {
        if let image = receiptImage {
            Button {
                showReceiptPreview = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("レシート画像", systemImage: "doc.text.viewfinder")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("タップで拡大")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .surfaceCard(padding: 14)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - 保存・削除

    private var saveBar: some View {
        VStack(spacing: 6) {
            PrimaryActionButton(
                title: isEditing ? "変更を保存" : "登録する",
                symbol: "checkmark.circle.fill",
                isEnabled: isValid
            ) {
                save()
            }
            .accessibilityIdentifier("editor.saveButton")

            if !isValid {
                Text("項目名と金額を入力してください")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            Theme.backgroundElevated.opacity(0.98)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(height: 1)
                }
        )
    }

    @ViewBuilder
    private var deleteSection: some View {
        if isEditing {
            Button {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                    Text("この支出を削除")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.danger.opacity(0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.danger.opacity(0.24), lineWidth: 1)
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    @ViewBuilder
    private var metadataFooter: some View {
        if let expense {
            VStack(spacing: 3) {
                Text("登録: \(DateLabels.fullDayTitle(expense.createdAt)) \(DateLabels.time(expense.createdAt))")
                Text("更新: \(DateLabels.fullDayTitle(expense.updatedAt)) \(DateLabels.time(expense.updatedAt))")
                if let merchant = expense.merchantName, !merchant.isEmpty {
                    Text(merchant)
                }
            }
            .font(.system(size: 9.5))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    // MARK: - 保存

    private func save() {
        guard isValid else {
            Haptics.warning()
            return
        }

        let amount = JPYFormat.amount(from: amountText)

        if let expense {
            let succeeded = model.updateExpense(
                expense,
                title: title,
                amount: amount,
                category: category,
                date: date,
                memo: memo
            )
            if succeeded {
                Haptics.success()
                dismiss()
            } else {
                Haptics.error()
            }
        } else {
            let saved = model.addExpense(
                title: title,
                amount: amount,
                category: category,
                date: date,
                memo: memo
            )
            if saved != nil {
                Haptics.success()
                dismiss()
            } else {
                Haptics.error()
            }
        }
    }
}
