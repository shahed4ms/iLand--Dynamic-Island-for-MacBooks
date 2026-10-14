
import Foundation
import Combine
import IOKit.ps

@MainActor
final class BatteryService: ObservableObject {
    @Published private(set) var percentage: Int = 0
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    @Published private(set) var isAvailable = false

    private var timer: Timer?

    func startPolling() {
        guard timer == nil else { return }
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue()
            as [CFTypeRef]

        guard !sources.isEmpty else {
            isAvailable = false
            isCharging = false
            isPluggedIn = false
            return
        }

        for source in sources {
            guard let description =
                IOPSGetPowerSourceDescription(info, source)?
                    .takeUnretainedValue() as? [String: Any]
            else {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey as String]
                as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey as String]
                as? Int ?? 100

            percentage = maximum > 0
                ? min(100, max(0, Int(Double(current) / Double(maximum) * 100)))
                : 0

            isCharging = description[kIOPSIsChargingKey as String]
                as? Bool ?? false

            let powerState =
                description[kIOPSPowerSourceStateKey as String] as? String

            isPluggedIn = powerState == (kIOPSACPowerValue as String)
            isAvailable = true
            return
        }

        isAvailable = false
    }
}
