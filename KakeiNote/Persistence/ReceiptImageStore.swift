import Foundation
import UIKit

/// レシート画像を Application Support 配下に JPEG で保存する。
/// 支出データにはファイル名だけを持たせ、Core Data を肥大化させない。
final class ReceiptImageStore {
    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base
                .appendingPathComponent("KakeiNote", isDirectory: true)
                .appendingPathComponent("Receipts", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    @discardableResult
    func save(_ image: UIImage, quality: CGFloat = 0.82) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw ReceiptImageStoreError.encodingFailed
        }
        let name = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return name
    }

    func image(named name: String) -> UIImage? {
        guard isValid(name: name) else { return nil }
        let url = directory.appendingPathComponent(name)
        return UIImage(contentsOfFile: url.path)
    }

    func delete(named name: String) {
        guard isValid(name: name) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    func exists(named name: String) -> Bool {
        guard isValid(name: name) else { return false }
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
    }

    /// 孤児画像の掃除（起動時に参照されていない画像を削除）。
    func removeOrphans(referencedNames: Set<String>) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in urls where !referencedNames.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func isValid(name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("..")
    }
}

enum ReceiptImageStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "レシート画像の保存に失敗しました。"
        }
    }
}
