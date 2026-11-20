import SwiftUI
import UIKit

struct EntryView: View {
    @EnvironmentObject private var model: AppModel

    @State private var title = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var date = Date()
    @State private var memo = ""

    @State private var showScanOptions = false
    @State private var pickerSource: ImagePickerSource?
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var scanError: String?
    @State private var reviewPayload: ReceiptReviewPayload?
    @State private var pendingImageName: String?
    @State private var reviewDidSave = false

    @State private var editingExpense: Expense?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case amount
        case memo
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && JPYFormat.amount(from: amountText) > 0
    }

    private var todayExpenses: [Expense] {
        model.todayExpenses()
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    scanCard
                    amountCard
                    detailsCard
                    categoryCard
                    todaySection
                    privacyFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveBar
            }

            if isProcessing {
                processingOverlay
            }
        }
        .confirmationDialog("レシートを読み取る", isPresented: $showScanOptions, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("カメラで撮影") {
                    pickerSource = ImagePickerSource(sourceType: .camera)
                }
            }
            Button("写真ライブラリから選択") {
                pickerSource = ImagePickerSource(sourceType: .photoLibrary)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("レシート全体が入るように、明るい場所で撮影してください。")
        }
        .fullScreenCover(item: $pickerSource) { source in
            ImagePicker(sourceType: source.sourceType, image: $capturedImage)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { newValue in
            guard let image = newValue else { return }
            capturedImage = nil
            process(image: image)
        }
        .sheet(item: $reviewPayload, onDismiss: {
            if !reviewDidSave {
                model.discardReceiptImage(named: pendingImageName)
            }
            pendingImageName = nil
            reviewDidSave = false
        }) { payload in
            ReceiptReviewView(payload: payload) { saved in
                reviewDidSave = saved
            }
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditorView(expense: expense, defaultDate: expense.date)
        }
        .alert("読み取れませんでした", isPresented: scanErrorBinding) {
            Button("手入力する") {
                focusedField = .title
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(scanError ?? "")
        }
        .keyboardDone {
            focusedField = nil
        }
        .onAppear(perform: presentSampleReviewIfRequested)
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("KAKEINOTE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.4)
                    .foregroundStyle(Theme.accent)

                Text(DateLabels.dayTitle(Date()))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("今日の支出")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(JPYFormat.yen(model.todayTotal()))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .padding(.top, 4)
    }

    // MARK: - レシート

    private var scanCard: some View {
        Button {
            showScanOptions = true
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text("レシートから入力")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("撮影して商品と金額を自動で読み取ります")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.16), Theme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("entry.scanButton")
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
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                AmountTextField(
                    text: $amountText,
                    placeholder: "0",
                    fontSize: 46,
                    accessibilityID: "entry.amountField"
                )
                .focused($focusedField, equals: .amount)
                .frame(minHeight: 54)
            }

            Text("3桁区切りで自動整形されます")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
        .surfaceCard(padding: 16)
        .overlay(alignment: .bottomLeading) {
            if focusedField == .amount {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(height: 2)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - 項目名・日付・メモ

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "項目名")
                Spacer()
                Text("必須")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accentSoft))
            }

            HStack(spacing: 8) {
                TextField("例：スーパーでの買い物", text: $title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .amount }
                    .accessibilityIdentifier("entry.titleField")

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

            Divider().overlay(Theme.stroke)

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("日付")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .tint(Theme.accent)
                    .accessibilityIdentifier("entry.datePicker")
            }

            Divider().overlay(Theme.stroke)

            SectionLabel(text: "メモ", optional: true)

            TextField("お店の名前など（任意）", text: $memo, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1...3)
                .focused($focusedField, equals: .memo)
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

    // MARK: - 保存

    private var saveBar: some View {
        VStack(spacing: 6) {
            PrimaryActionButton(
                title: "登録する",
                symbol: "plus.circle.fill",
                isEnabled: isFormValid
            ) {
                saveExpense()
            }
            .accessibilityIdentifier("entry.saveButton")

            if !isFormValid {
                Text("項目名と金額を入力すると登録できます")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            Theme.background.opacity(0.97)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(height: 1)
                }
        )
    }

    // MARK: - 今日の記録

    @ViewBuilder
    private var todaySection: some View {
        if !todayExpenses.isEmpty {
            let visible = Array(todayExpenses.prefix(5))
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("今日の記録")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(todayExpenses.count)件 · \(JPYFormat.yen(todayExpenses.reduce(0) { $0 + $1.amount }))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 15)
                .padding(.bottom, 2)

                ForEach(Array(visible.enumerated()), id: \.element.id) { index, expense in
                    Button {
                        editingExpense = expense
                    } label: {
                        ExpenseRowContent(expense: expense)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(PressableButtonStyle())

                    if index < visible.count - 1 {
                        ExpenseDivider()
                            .padding(.trailing, 16)
                    }
                }

                if todayExpenses.count > visible.count {
                    Text("ほか \(todayExpenses.count - visible.count)件はカレンダーで確認できます")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
            .padding(.bottom, 4)
            .surfaceCard(padding: 0)
            .accessibilityIdentifier("entry.todaySection")
        }
    }

    private var privacyFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("支出データはこの端末の中だけに保存されます")
                .font(.system(size: 10))
        }
        .foregroundStyle(Theme.textTertiary)
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 処理中

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.66).ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(Theme.accent)

                Text("レシートを解析中…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text("文字と金額を読み取っています")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surfaceHigh)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.strokeStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        }
        .transition(.opacity)
        .zIndex(50)
    }

    // MARK: - アクション

    private func saveExpense() {
        guard isFormValid else {
            Haptics.warning()
            return
        }

        let amount = JPYFormat.amount(from: amountText)
        let saved = model.addExpense(
            title: title,
            amount: amount,
            category: category,
            date: date,
            memo: memo
        )

        guard saved != nil else {
            Haptics.error()
            return
        }

        Haptics.success()
        withAnimation(.easeOut(duration: 0.2)) {
            title = ""
            amountText = ""
            memo = ""
        }
        focusedField = nil
    }

    private func process(image: UIImage) {
        isProcessing = true
        Task { @MainActor in
            do {
                let result = try await ReceiptOCRService.scan(image)
                let parsed = ReceiptParser().parse(result.text, referenceDate: Date())
                let imageName = try model.saveReceiptImage(result.displayImage)
                pendingImageName = imageName
                reviewPayload = ReceiptReviewPayload(
                    parsed: parsed,
                    image: result.displayImage,
                    imageName: imageName
                )
            } catch {
                scanError = error.localizedDescription
                Haptics.error()
            }
            isProcessing = false
        }
    }

    // MARK: - UI テスト用サンプル

    /// `-UITEST_RECEIPT_REVIEW` 起動時のみ、カメラを使わずに確認画面を開く。
    private func presentSampleReviewIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-UITEST_RECEIPT_REVIEW"),
              reviewPayload == nil else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard reviewPayload == nil else { return }

            let lines = [
                "イオンスタイル 渋谷店",
                Self.sampleDateFormatter.string(from: Date()),
                "牛乳 1L              ¥198",
                "たまご 10個           ¥248",
                "洗剤 詰替 398",
                "ティッシュ 5箱        328",
                "小計                 ¥1,172",
                "消費税(8%)            ¥93",
                "合計                 ¥1,265"
            ]
            let text = lines.joined(separator: "\n")
            let parsed = ReceiptParser().parse(text, referenceDate: Date())
            let image = Self.makeSampleReceiptImage(lines: lines)
            let imageName = try? model.saveReceiptImage(image)
            pendingImageName = imageName
            reviewPayload = ReceiptReviewPayload(
                parsed: parsed,
                image: image,
                imageName: imageName
            )
        }
    }

    /// サンプルレシートの日付行。実行日の日付を使い、明細が必ず「今日」に登録されるようにする。
    private static let sampleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = KakeiCalendar.calendar
        formatter.dateFormat = "yyyy年M月d日 H:mm"
        return formatter
    }()

    private static func makeSampleReceiptImage(lines: [String]) -> UIImage {
        let size = CGSize(width: 900, height: 1100)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.97, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .medium),
                .foregroundColor: UIColor.black
            ]

            for (index, line) in lines.enumerated() {
                line.draw(at: CGPoint(x: 48, y: 56 + CGFloat(index) * 78), withAttributes: attributes)
            }
        }
    }

    private var scanErrorBinding: Binding<Bool> {
        Binding(
            get: { scanError != nil },
            set: { newValue in
                if !newValue { scanError = nil }
            }
        )
    }
}
