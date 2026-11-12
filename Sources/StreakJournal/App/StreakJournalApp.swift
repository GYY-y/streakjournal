import SwiftUI

@main
struct StreakJournalApp: App {
    @StateObject private var store = Store.shared
    @AppStorage("appearance") private var appearance: String = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(colorScheme)
                .frame(minWidth: 980, minHeight: 660)
                .task { Store.shared.bootstrap() }        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("手动备份") { Store.shared.manualBackup() }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
