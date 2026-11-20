import SwiftUI

enum AppTab: Hashable {
    case entry
    case calendar
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: AppTab = .entry

    var body: some View {
        TabView(selection: $selection) {
            EntryView()
                .tag(AppTab.entry)
                .tabItem {
                    Label("入力", systemImage: "square.and.pencil")
                }

            CalendarView()
                .tag(AppTab.calendar)
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
        }
        .tint(Theme.accent)
        .overlay(alignment: .top) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: model.toast)
        .alert("エラー", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .tint(Theme.accent)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { newValue in
                if !newValue { model.errorMessage = nil }
            }
        )
    }
}
