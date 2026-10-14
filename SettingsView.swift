import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("iLand.selectedDeviceType") private var selectedDeviceType = "MacBook"
    @AppStorage("iLand.selectedDeviceModel") private var selectedDeviceModel = "MacBook Air M1"

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?

    private let deviceTypes = ["MacBook", "iPhone"]

    private var availableModels: [String] {
        switch selectedDeviceType {
        case "iPhone":
            return [
                "iPhone X",
                "iPhone XS",
                "iPhone XS Max",
                "iPhone XR",
                "iPhone 11",
                "iPhone 11 Pro",
                "iPhone 11 Pro Max",
                "iPhone 12",
                "iPhone 12 mini",
                "iPhone 12 Pro",
                "iPhone 12 Pro Max",
                "iPhone 13",
                "iPhone 13 mini",
                "iPhone 13 Pro",
                "iPhone 13 Pro Max",
                "iPhone 14",
                "iPhone 14 Plus",
                "iPhone 14 Pro",
                "iPhone 14 Pro Max"
            ]
        default:
            return [
                "MacBook Air M1",
                "MacBook Air M2",
                "MacBook Air M3",
                "MacBook Air M4",
                "Latest MacBook Air"
            ]
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Device type", selection: $selectedDeviceType) {
                    ForEach(deviceTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedDeviceType) { _, newType in
                    let models = models(for: newType)
                    selectedDeviceModel = models.first ?? ""
                }

                Picker("Device model", selection: $selectedDeviceModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .onChange(of: selectedDeviceModel) { _, _ in
                    // The selected profile is persisted by AppStorage.
                    // Use this preference elsewhere in iLand if the layout
                    // should adapt to the selected device.
                }

                Label {
                    Text("Selected: \(selectedDeviceModel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: selectedDeviceType == "iPhone" ? "iphone" : "laptopcomputer")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Device")
            } footer: {
                Text("Choose the device profile iLand should use. This does not change your Mac's actual hardware.")
            }

            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLaunchAtLogin(enabled)
                    }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("General")
            } footer: {
                Text("Open iLand automatically when you sign in to your Mac.")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 440, height: 360)
        .navigationTitle("iLand Settings")
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if !availableModels.contains(selectedDeviceModel) {
                selectedDeviceModel = availableModels.first ?? ""
            }
        }
    }

    private func models(for type: String) -> [String] {
        if type == "iPhone" {
            return [
                "iPhone X", "iPhone XS", "iPhone XS Max", "iPhone XR",
                "iPhone 11", "iPhone 11 Pro", "iPhone 11 Pro Max",
                "iPhone 12", "iPhone 12 mini", "iPhone 12 Pro", "iPhone 12 Pro Max",
                "iPhone 13", "iPhone 13 mini", "iPhone 13 Pro", "iPhone 13 Pro Max",
                "iPhone 14", "iPhone 14 Plus", "iPhone 14 Pro", "iPhone 14 Pro Max"
            ]
        }

        return [
            "MacBook Air M1",
            "MacBook Air M2",
            "MacBook Air M3",
            "MacBook Air M4",
            "Latest MacBook Air"
        ]
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            errorMessage = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }
}
