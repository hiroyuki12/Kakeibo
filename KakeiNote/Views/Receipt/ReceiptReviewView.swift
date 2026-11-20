import SwiftUI
import UIKit

struct ReceiptReviewPayload: Identifiable {
    let id = UUID()
    let parsed: ParsedReceipt
    let image: UIImage?
    let imageName: String?
}

/// OCR 結果をユーザーが確認・修正して登録する画面。
struct ReceiptReviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let payload: ReceiptReviewPayload
    let onFinish: (Bool) -> Void

    @State private var items: [ReceiptDraftItem]
    @State private var merchant: String
    @State private var date: Date
    @State private var declaredTotalText: String
    @State private var mode: RegisterMode
    @State private var singleTitle: String
    @State private var singleCategory: ExpenseCategory
    @State private var showRawText = false
    @State private var showImagePreview = false
    @State private var showMismatchConfirm = false
    @State private var pendingSaveItems: [ReceiptDraftItem]?
    @State private var saveError: String?
    @State private var showErrorAlert = false

    private enum RegisterMode: String, CaseIterable, Identifiable {
        case details
        case single

        var id: String { rawValue }

        var label: String {
            switch self {
            case .details: return "明細ごとに登録"
            case .single: return "合計で1件登録"
            }
        }
    }

    init(payload: ReceiptReviewPayload, onFinish: @escaping (Bool) -> Void) {
        self.payload = payload
        self.onFinish = onFinish

        let parsed = payload.parsed
        _items = State(initialValue: parsed.items.map {
            ReceiptDraftItem(
                title: $0.name,
                amount: $0.amount,
                category: $0.category,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        })
        _merchant = State(initialValue: parsed.merchantName ?? "")
        _date = State(initialValue: parsed.date ?? KakeiCalendar.startOfDay(Date()))
        _declaredTotalText = State(initialValue: parsed.declaredTotal.map { JPYFormat.grouped(String($0)) } ?? "")
        _mode = State(initialValue: parsed.items.isEmpty ? .single : .details)
        _singleTitle = State(initialValue: parsed.merchantName ?? "レシート")
        _singleCategory = State(initialValue: parsed.items.first?.category ?? .other)
    }

    private var declaredTotalValue: Int {
        JPYFormat.amount(from: declaredTotalText)
    }

    private var itemsTotal: Int {
        items.reduce(0) { $0 + $1.amount }
    }

    private var validItems: [ReceiptDraftItem] {
        items.filter {
            $0.amount > 0 && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var merchantOrNil: String? {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var displayTotal: Int {
        if mode == .single {
            return declaredTotalValue > 0 ? declaredTotalValue : itemsTotal
        }
        return itemsTotal
    }

    private var canSave: Bool {
        if mode == .single {
            return displayTotal > 0
        }
        return !items.isEmpty
    }

    private var hasMismatch: Bool {
        mode == .details
            && declaredTotalValue > 0
            && !items.isEmpty
            && declaredTotalValue != itemsTotal
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    imageCard
                    summaryCard

                    if !items.isEmpty {
                        modePicker
                    }

                    if mode == .details {
                        itemsSection
                    } else {
                        singleRegistrationCard
                    }

                    rawTextCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("読み取り結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        finish(saved: false)
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveBar
            }
            .sheet(isPresented: $showImagePreview) {
                if let image = payload.image {
                    ReceiptImageViewer(image: image, title: "レシート画像")
                }
            }
            .alert("合計金額が一致しません", isPresented: $showMismatchConfirm) {
                Button("明細合計で登録") {
                    if let pendingSaveItems {
                        performSave(items: pendingSaveItems)
                    }
                }
                Button("戻る", role: .cancel) {
                    pendingSaveItems = nil
                }
            } message: {
                Text("明細合計 \(JPYFormat.yen(itemsTotal)) とレシート合計 \(JPYFormat.yen(declaredTotalValue)) が一致しません。このまま明細合計で登録しますか？")
            }
            .alert("確認してください", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .keyboardDone {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    // MARK: - 画像

    private var imageCard: some View {
        Button {
            if payload.image != nil {
                showImagePreview = true
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let image = payload.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 156)
                        .clipped()
                } else {
                    ZStack {
                        Theme.surfaceHigh
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(height: 120)
                }

                if payload.image != nil {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("拡大")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(10)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - 概要

    private var summaryCard: some View {
        VStack(spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: "storefront")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                TextField("店舗名", text: $merchant)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Divider().overlay(Theme.stroke)

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .semibold))
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

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("レシート合計")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text("読み取れなかった場合は空欄でも登録できます")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("¥")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("0", text: Binding(
                        get: { declaredTotalText },
                        set: { declaredTotalText = JPYFormat.formattedInput($0) }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .frame(width: 116)
                    .accessibilityIdentifier("receipt.declaredTotal")
                }
            }
        }
        .surfaceCard(padding: 16)
    }

    // MARK: - 登録モード

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(RegisterMode.allCases) { candidate in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        mode = candidate
                    }
                    Haptics.selection()
                } label: {
                    Text(candidate.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(mode == candidate ? Color.white : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(mode == candidate ? Theme.accent.opacity(0.85) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceHigh)
        )
    }

    // MARK: - 明細

    private var itemsSection: some View {
        VStack(spacing: 10) {
            if hasMismatch {
                mismatchBanner
            }

            HStack {
                Text("明細")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(items.count)件")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("合計 \(JPYFormat.yen(itemsTotal))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }

            ForEach($items) { $item in
                ReceiptItemEditorCard(item: $item) {
                    removeItem(id: item.id)
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    items.append(ReceiptDraftItem(title: "", amount: 0, category: .other))
                }
                Haptics.selection()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("明細を追加")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Theme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var mismatchBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.warning)
                Text("合計金額が一致しません")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.warning)
                Spacer()
                Text("差額 \(JPYFormat.yen(declaredTotalValue - itemsTotal))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.warning)
                    .monospacedDigit()
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("明細合計")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                    Text(JPYFormat.yen(itemsTotal))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("レシート合計")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                    Text(JPYFormat.yen(declaredTotalValue))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
                Spacer()
            }

            if declaredTotalValue > itemsTotal {
                Button {
                    addAdjustment()
                } label: {
                    Text("差額を「調整」として明細に追加")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.warning)
                }
                .buttonStyle(.plain)
            } else {
                Text("明細の金額がレシート合計を上回っています。入力内容を確認してください。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.warning.opacity(0.9))
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.warning.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Theme.warning.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 合計で1件登録

    private var singleRegistrationCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(items.isEmpty
                     ? "明細を自動で読み取れませんでした。合計金額から1件として登録できます。"
                     : "レシート全体を1件の支出として登録します。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SectionLabel(text: "項目名")

            TextField("レシート", text: $singleTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Divider().overlay(Theme.stroke)

            SectionLabel(text: "カテゴリ")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExpenseCategory.allCases) { category in
                        Button {
                            singleCategory = category
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.symbolName)
                                    .font(.system(size: 10, weight: .semibold))
                                Text(category.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(singleCategory == category ? Color.white : category.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(singleCategory == category ? category.tint.opacity(0.85) : category.tint.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .surfaceCard(padding: 16)
    }

    // MARK: - 生テキスト

    private var rawTextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showRawText.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("読み取ったテキスト")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Image(systemName: showRawText ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if showRawText {
                Divider().overlay(Theme.stroke)
                ScrollView {
                    Text(payload.parsed.rawText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 220)
            }
        }
        .surfaceCard(padding: 15)
    }

    // MARK: - 保存バー

    private var saveBar: some View {
        VStack(spacing: 9) {
            HStack {
                Text(mode == .details ? "明細合計" : "登録金額")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(JPYFormat.yen(displayTotal))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }

            PrimaryActionButton(
                title: mode == .details ? "\(validItems.count)件を登録する" : "1件を登録する",
                symbol: "checkmark.circle.fill",
                isEnabled: canSave
            ) {
                register()
            }
            .accessibilityIdentifier("receipt.saveButton")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Theme.backgroundElevated
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(height: 1)
                }
        )
    }

    // MARK: - 操作

    private func removeItem(id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            items.removeAll { $0.id == id }
        }
        Haptics.selection()
    }

    private func addAdjustment() {
        let difference = declaredTotalValue - itemsTotal
        guard difference > 0 else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            items.append(ReceiptDraftItem(
                title: "調整（税・割引など）",
                amount: difference,
                category: .other
            ))
        }
        Haptics.selection()
    }

    private func register() {
        switch mode {
        case .single:
            let amount = displayTotal
            guard amount > 0 else {
                presentValidationError("登録する金額を入力してください。")
                return
            }
            let trimmed = singleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let saved = model.addExpense(
                title: trimmed.isEmpty ? "レシート" : trimmed,
                amount: amount,
                category: singleCategory,
                date: date,
                memo: merchantOrNil ?? "レシートから登録",
                receiptImageName: payload.imageName,
                receiptGroupID: UUID(),
                merchantName: merchantOrNil
            )
            if saved != nil {
                Haptics.success()
                finish(saved: true)
            } else {
                presentModelError()
            }

        case .details:
            guard !items.isEmpty else {
                presentValidationError("明細がありません。合計で1件登録するか、明細を追加してください。")
                return
            }
            guard validItems.count == items.count else {
                presentValidationError("商品名と金額が未入力の明細があります。すべて入力するか、不要な明細を削除してください。")
                return
            }
            guard !validItems.isEmpty else {
                presentValidationError("登録する明細がありません。")
                return
            }

            if declaredTotalValue > 0 && declaredTotalValue != itemsTotal {
                pendingSaveItems = validItems
                showMismatchConfirm = true
            } else {
                performSave(items: validItems)
            }
        }
    }

    private func performSave(items: [ReceiptDraftItem]) {
        let count = model.addReceiptItems(
            items,
            merchantName: merchantOrNil,
            date: date,
            receiptImageName: payload.imageName
        )
        if count > 0 {
            Haptics.success()
            finish(saved: true)
        } else {
            presentModelError()
        }
    }

    private func finish(saved: Bool) {
        onFinish(saved)
        dismiss()
    }

    private func presentValidationError(_ message: String) {
        saveError = message
        showErrorAlert = true
        Haptics.warning()
    }

    private func presentModelError() {
        saveError = model.errorMessage ?? "保存に失敗しました。"
        model.errorMessage = nil
        showErrorAlert = true
        Haptics.error()
    }
}

// MARK: - 明細編集カード

private struct ReceiptItemEditorCard: View {
    @Binding var item: ReceiptDraftItem
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("商品名", text: $item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("receipt.itemTitle")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.danger.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.danger.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Text("¥")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("0", text: Binding(
                        get: { item.amount == 0 ? "" : JPYFormat.grouped(String(item.amount)) },
                        set: { item.amount = JPYFormat.amount(from: $0) }
                    ))
                    .keyboardType(.numberPad)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .frame(width: 92)
                    .accessibilityIdentifier("receipt.itemAmount")
                }

                Spacer(minLength: 4)

                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }

                Menu {
                    ForEach(ExpenseCategory.allCases) { category in
                        Button {
                            item.category = category
                            Haptics.selection()
                        } label: {
                            Label(category.displayName, systemImage: category.symbolName)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.category.tint)
                            .frame(width: 7, height: 7)
                        Text(item.category.displayName)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(item.category.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(item.category.tint.opacity(0.13)))
                }
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}
