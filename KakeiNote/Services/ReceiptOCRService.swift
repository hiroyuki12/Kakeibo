import CoreImage
import Foundation
import UIKit
import Vision

/// レシート画像の前処理。向き補正 → 台形補正 → コントラスト調整 → 縮小。
enum ReceiptImageProcessor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// 表示・保存用。向きを正し、長辺を maxDimension に収める。
    static func uprightImage(_ image: UIImage, maxDimension: CGFloat = 2600) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        let ratio = longest > maxDimension ? maxDimension / longest : 1

        if image.imageOrientation == .up && ratio >= 1 {
            return image
        }

        let targetSize = CGSize(
            width: max(1, (pixelWidth * ratio).rounded()),
            height: max(1, (pixelHeight * ratio).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// OCR 用の前処理。失敗しても元画像を返し、認識自体は継続する。
    static func prepareForOCR(_ image: UIImage) -> UIImage {
        let upright = uprightImage(image, maxDimension: 2600)
        guard let ciImage = CIImage(image: upright) else { return upright }

        let corrected = perspectiveCorrected(ciImage) ?? ciImage

        guard let filter = CIFilter(name: "CIColorControls") else { return upright }
        filter.setValue(corrected, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        filter.setValue(1.08, forKey: kCIInputContrastKey)
        filter.setValue(0.015, forKey: kCIInputBrightnessKey)

        var output = filter.outputImage ?? corrected
        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(output, forKey: kCIInputImageKey)
            sharpen.setValue(0.35, forKey: kCIInputSharpnessKey)
            output = sharpen.outputImage ?? output
        }

        return render(output) ?? upright
    }

    /// レシートの四隅を検出できた場合だけ台形補正する。
    private static func perspectiveCorrected(_ image: CIImage) -> CIImage? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.55
        request.minimumSize = 0.25
        request.quadratureTolerance = 30
        request.minimumAspectRatio = 0.15

        let handler = VNImageRequestHandler(ciImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let rectangle = request.results?.first else { return nil }

        let extent = image.extent
        let width = extent.width
        let height = extent.height
        func vector(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x * width, y: point.y * height)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(vector(rectangle.topLeft), forKey: "inputTopLeft")
        filter.setValue(vector(rectangle.topRight), forKey: "inputTopRight")
        filter.setValue(vector(rectangle.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(vector(rectangle.bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return nil }
        let aspect = output.extent.width / max(1, output.extent.height)
        guard aspect > 0.15, aspect < 4.5 else { return nil }
        return output
    }

    private static func render(_ image: CIImage) -> UIImage? {
        let extent = image.extent
        guard extent.width > 1, extent.height > 1 else { return nil }
        guard let cgImage = ciContext.createCGImage(image, from: extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct ReceiptOCRResult {
    let text: String
    let lineCount: Int
    /// 向き補正済みの画像（保存・確認画面表示用）。
    let displayImage: UIImage
}

enum ReceiptOCRError: LocalizedError {
    case imageUnavailable
    case noTextFound
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            return "画像を読み込めませんでした。"
        case .noTextFound:
            return "レシートの文字を読み取れませんでした。明るい場所で撮り直すか、手入力してください。"
        case .recognitionFailed(let message):
            return "文字認識に失敗しました: \(message)"
        }
    }
}

/// Vision の VNRecognizeTextRequest を使った日本語 OCR。
enum ReceiptOCRService {
    static func scan(_ image: UIImage) async throws -> ReceiptOCRResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let displayImage = ReceiptImageProcessor.uprightImage(image, maxDimension: 2600)
                    let prepared = ReceiptImageProcessor.prepareForOCR(image)
                    guard let cgImage = prepared.cgImage else {
                        throw ReceiptOCRError.imageUnavailable
                    }

                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["ja-JP", "en-US"]
                    request.usesLanguageCorrection = true
                    request.automaticallyDetectsLanguage = true
                    request.minimumTextHeight = 0.005
                    request.customWords = [
                        "合計", "小計", "税込", "税抜", "消費税", "お預り", "お釣り",
                        "領収書", "レシート", "軽減税率", "割引", "値引", "クーポン",
                        "円", "点", "個", "袋", "牛乳", "卵", "洗剤", "ティッシュ"
                    ]

                    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                    try handler.perform([request])

                    let observations = request.results ?? []
                    let lines = orderedLines(from: observations)
                    let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { throw ReceiptOCRError.noTextFound }

                    continuation.resume(returning: ReceiptOCRResult(
                        text: text,
                        lineCount: lines.count,
                        displayImage: displayImage
                    ))
                } catch let error as ReceiptOCRError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: ReceiptOCRError.recognitionFailed(error.localizedDescription))
                }
            }
        }
    }

    /// テスト用にテキストだけ返す。
    static func recognizeText(in image: UIImage) async throws -> String {
        try await scan(image).text
    }

    /// 同じ行にある列をまとめ、上から下・左から右の順に並べる。
    private static func orderedLines(from observations: [VNRecognizedTextObservation]) -> [String] {
        let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[VNRecognizedTextObservation]] = []

        for observation in sorted {
            if let anchor = rows.last?.first,
               abs(anchor.boundingBox.midY - observation.boundingBox.midY) < 0.012 {
                rows[rows.count - 1].append(observation)
            } else {
                rows.append([observation])
            }
        }

        var lines: [String] = []
        for row in rows {
            let ordered = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            for observation in ordered {
                if let candidate = observation.topCandidates(1).first {
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        lines.append(text)
                    }
                }
            }
        }
        return lines
    }
}
