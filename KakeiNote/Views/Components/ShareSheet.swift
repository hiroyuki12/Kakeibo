import SwiftUI
import UIKit

/// UIActivityViewController を SwiftUI から使うための橋渡し。
/// CSV 書き出しファイルを「ファイルに保存」「AirDrop」「メッセージ」などへ渡す。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
