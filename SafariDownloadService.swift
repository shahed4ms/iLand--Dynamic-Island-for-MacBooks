
import Foundation
import Combine

struct SafariDownloadInfo: Equatable {
    var fileName: String
    var bytesDownloaded: Int64
    var totalBytes: Int64?
    var speedBytesPerSecond: Double
    var estimatedSecondsRemaining: Double?

    var progress: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return min(max(Double(bytesDownloaded) / Double(totalBytes), 0), 1)
    }
}

@MainActor
final class SafariDownloadService: ObservableObject {
    @Published private(set) var download: SafariDownloadInfo?

    private var timer: Timer?
    private var previousSizes: [String: (bytes: Int64, date: Date)] = [:]

    private let downloadsURL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)

    func startPolling() {
        guard timer == nil else { return }
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
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
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            download = nil
            return
        }

        let candidates = items.filter {
            $0.lastPathComponent.lowercased().hasSuffix(".download")
        }

        guard let item = candidates.max(by: {
            modifiedDate($0) < modifiedDate($1)
        }) else {
            download = nil
            previousSizes.removeAll()
            return
        }

        let now = Date()
        let bytes = recursiveFileSize(item)
        let key = item.path
        var speed = 0.0

        if let previous = previousSizes[key] {
            let elapsed = now.timeIntervalSince(previous.date)
            if elapsed > 0 {
                speed = max(0, Double(bytes - previous.bytes) / elapsed)
            }
        }

        previousSizes[key] = (bytes, now)

        let total = findTotalBytes(in: item)
        let eta: Double?

        if let total, total >= bytes, speed > 0 {
            eta = Double(total - bytes) / speed
        } else {
            eta = nil
        }

        download = SafariDownloadInfo(
            fileName: item.deletingPathExtension().lastPathComponent,
            bytesDownloaded: bytes,
            totalBytes: total,
            speedBytesPerSecond: speed,
            estimatedSecondsRemaining: eta
        )
    }

    private func modifiedDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(
            forKeys: [.contentModificationDateKey]
        )
        return values?.contentModificationDate ?? .distantPast
    }

    private func recursiveFileSize(_ url: URL) -> Int64 {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false

        guard manager.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ) else { return 0 }

        if !isDirectory.boolValue {
            let attributes = try? manager.attributesOfItem(atPath: url.path)
            return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        }

        guard let enumerator = manager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey]
            )
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }

        return total
    }

    private func findTotalBytes(in item: URL) -> Int64? {
        let manager = FileManager.default
        var urls: [URL] = []

        if let enumerator = manager.enumerator(
            at: item,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "plist" {
                    urls.append(url)
                }
            }
        }

        for url in urls {
            guard
                let data = try? Data(contentsOf: url),
                let plist = try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ),
                let dictionary = plist as? [String: Any]
            else { continue }

            if let total = dictionary[
                "DownloadEntryProgressTotalToLoad"
            ] as? NSNumber, total.int64Value > 0 {
                return total.int64Value
            }
        }

        return nil
    }
}
