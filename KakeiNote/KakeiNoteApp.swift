import SwiftUI
import UIKit

@main
struct KakeiNoteApp: App {
    @StateObject private var model = AppModel()

    init() {
        AppAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

enum AppAppearance {
    static func configure() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Theme.background)
        tabAppearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

        let itemAppearance = tabAppearance.stackedLayoutAppearance
        itemAppearance.normal.iconColor = UIColor(Theme.textTertiary)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.textTertiary)]
        itemAppearance.selected.iconColor = UIColor(Theme.accent)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.accent)]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = UIColor(Theme.background)
        navigationAppearance.shadowColor = .clear
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary)]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary)]

        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().tintColor = UIColor(Theme.accent)

        UITextField.appearance().tintColor = UIColor(Theme.accent)
        UIDatePicker.appearance().tintColor = UIColor(Theme.accent)
    }
}
