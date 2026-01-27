import SwiftUI

/// A simple settings screen that allows the user to enable or disable background updates.
///
/// The setting is stored in ``AppStorage`` so it persists across app launches.
struct SettingsView: View {
    /// Flag to enable background updates.
    @AppStorage("backgroundUpdatesEnabled") private var backgroundUpdatesEnabled: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Toggle(
                    "Background Updates",
                    isOn: $backgroundUpdatesEnabled
                )
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
