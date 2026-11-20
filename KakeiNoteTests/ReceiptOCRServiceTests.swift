import XCTest
import UIKit
@testable import KakeiNote

final class ReceiptOCRServiceTests: XCTestCase {
    private func makeReceiptImage(lines: [String]) -> UIImage {
        let size = CGSize(width: 1000, height: 760)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .medium),
                .foregroundColor: UIColor.black
            ]

            for (index, line) in lines.enumerated() {
                line.draw(
                    at: CGPoint(x: 56, y: 48 + CGFloat(index) * 82),
                    withAttributes: attributes
                )
            }
        }
    }

    func testJapaneseOCRReadsReceiptKeywords() async throws {
        let image = makeReceiptImage(lines: [
            "イオンスタイル 渋谷店",
            "2026年11月20日",
            "牛乳 198",
            "たまご 248",
            "洗剤 398",
            "合計 844"
        ])

        let text = try await ReceiptOCRService.recognizeText(in: image)

        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("合計"), "OCR結果: \(text)")
        XCTAssertTrue(text.contains("牛乳"), "OCR結果: \(text)")
        XCTAssertTrue(text.contains("198"), "OCR結果: \(text)")
    }

    func testOCROutputCanBeParsed() async throws {
        let image = makeReceiptImage(lines: [
            "スーパーABC",
            "2026年11月20日",
            "牛乳 198",
            "食パン 158",
            "合計 356"
        ])

        let text = try await ReceiptOCRService.recognizeText(in: image)
        let parsed = ReceiptParser().parse(text, referenceDate: Date())

        XCTAssertFalse(parsed.items.isEmpty, "OCR結果: \(text)")
        XCTAssertNotNil(parsed.merchantName, "OCR結果: \(text)")
        XCTAssertEqual(parsed.declaredTotal, 356, "OCR結果: \(text)")
    }

    func testPreprocessorPreservesImage() {
        let image = makeReceiptImage(lines: ["牛乳 198", "合計 198"])
        let processed = ReceiptImageProcessor.prepareForOCR(image)

        XCTAssertGreaterThan(processed.size.width, 0)
        XCTAssertGreaterThan(processed.size.height, 0)
        XCTAssertNotNil(processed.cgImage)
    }
}
