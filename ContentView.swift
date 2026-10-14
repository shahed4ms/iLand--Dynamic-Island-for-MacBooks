
import AppKit
import SwiftUI

// MARK: - Features

enum NotchDemoFeature: String, CaseIterable, Identifiable {
    case music = "Music"
    case copilot = "VS Code Copilot"
    case safari = "Safari Downloads"
    case appStore = "App Store Downloads"
    case battery = "Battery"

    var id: String { rawValue }
}

// MARK: - Notch Shape

struct MacNotchShape: Shape {
    var radius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.height / 2, rect.width / 2)

        var path = Path()

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))

        path.addQuadCurve(
            to: CGPoint(x: rect.width - r, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )

        path.addLine(to: CGPoint(x: r, y: rect.height))

        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - r),
            control: CGPoint(x: 0, y: rect.height)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var feature: NotchDemoFeature = .music
    @State private var isExpanded = false

    @StateObject private var musicService = MusicService()

    @State private var copilotNeedsPermission = false
    @State private var batteryPercent = 18
    @State private var isCharging = false
    @State private var minutesToFull = 35
    @State private var downloadProgress = 0.62

    private let panelWidth: CGFloat = 290
    private let compactHeight: CGFloat = 40
    private let musicHeight: CGFloat = 184
    private let downloadHeight: CGFloat = 164
    private let batteryHeight: CGFloat = 40

    private let animation = Animation.spring(
        response: 0.45,
        dampingFraction: 0.82
    )

    private var panelHeight: CGFloat {
        if feature == .battery {
            return batteryHeight
        }

        if feature == .copilot || !isExpanded {
            return compactHeight
        }

        switch feature {
        case .music:
            return musicHeight
        case .safari, .appStore:
            return downloadHeight
        case .copilot, .battery:
            return compactHeight
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ILAND — NOTCH PREVIEW")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Feature", selection: $feature) {
                    ForEach(NotchDemoFeature.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: feature) { _, newFeature in
                    withAnimation(animation) {
                        isExpanded = newFeature == .battery
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            notchContent
                .frame(
                    width: panelWidth,
                    height: panelHeight,
                    alignment: .top
                )
                .background(Color.black)
                .clipShape(MacNotchShape(radius: 10))
                .contentShape(MacNotchShape(radius: 10))
                .onTapGesture {
                    guard feature != .battery,
                          feature != .copilot else { return }

                    withAnimation(animation) {
                        isExpanded.toggle()
                    }
                }
                .animation(animation, value: isExpanded)
                .animation(animation, value: feature)

            controls
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 380)
        .preferredColorScheme(.dark)
        .task {
            musicService.startPolling()
        }
        .onDisappear {
            musicService.stopPolling()
        }
        .onChange(of: musicService.isPlaying) { _, playing in
            if playing && feature == .music {
                withAnimation(animation) {
                    isExpanded = true
                }
            }
        }
    }

    // MARK: - Feature Content

    @ViewBuilder
    private var notchContent: some View {
        switch feature {
        case .music:
            musicContent

        case .copilot:
            copilotContent

        case .safari:
            downloadContent(
                title: "Safari Downloads",
                symbol: "safari"
            )

        case .appStore:
            downloadContent(
                title: "App Store Downloads",
                symbol: "arrow.down.app"
            )

        case .battery:
            batteryContent
        }
    }

    // MARK: - Music Panel

    private var musicContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue, .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        musicService.title.isEmpty
                            ? "No music playing"
                            : musicService.title
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                    Text(
                        musicService.artist.isEmpty
                            ? "Apple Music"
                            : musicService.artist
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.top, isExpanded ? 48 : 4)

            if isExpanded {
                HStack(spacing: 30) {
                    Button {
                        Task {
                            await musicService.previousTrack()
                        }
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }

                    Button {
                        Task {
                            await musicService.playPause()
                        }
                    } label: {
                        Image(
                            systemName: musicService.isPlaying
                                ? "pause.fill"
                                : "play.fill"
                        )
                        .font(.system(size: 18))
                    }

                    Button {
                        Task {
                            await musicService.nextTrack()
                        }
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.top, 8)

                if let error = musicService.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(
            width: panelWidth,
            height: isExpanded ? musicHeight : compactHeight,
            alignment: .top
        )
        .background(Color.black)
    }

    // MARK: - Copilot Panel

    private var copilotContent: some View {
        HStack {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 18))
                .foregroundStyle(.white)

            Spacer()

            if copilotNeedsPermission {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: panelWidth, height: compactHeight)
        .background(Color.black)
    }

    // MARK: - Downloads Panel

    private func downloadContent(
        title: String,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 23))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(
                        downloadProgress >= 1
                            ? "Download complete"
                            : "Downloading"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
                }

                Spacer(minLength: 0)

                CircularDownloadMeter(progress: downloadProgress)
                    .frame(width: 25, height: 25)
            }
            .padding(.top, isExpanded ? 44 : 0)

            if isExpanded {
                ProgressView(value: downloadProgress)
                    .tint(.white)

                HStack {
                    Text("\(Int(downloadProgress * 100))% complete")
                    Spacer()
                    Text("Simulated")
                }
                .font(.system(size: 10))
                .foregroundStyle(.gray)

                Text(
                    downloadProgress >= 1
                        ? "Finished"
                        : "Speed: 8.4 MB/s"
                )
                .font(.system(size: 11))
                .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(
            width: panelWidth,
            height: panelHeight,
            alignment: .top
        )
        .background(Color.black)
    }

    // MARK: - Battery Panel

    private var batteryContent: some View {
        HStack {
            Image(
                systemName: isCharging
                    ? "battery.100percent.bolt"
                    : "battery.25percent"
            )
            .font(.system(size: 18))
            .foregroundStyle(isCharging ? .green : .red)

            Spacer()

            Text(
                isCharging
                    ? "\(minutesToFull)m"
                    : "\(batteryPercent)%"
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isCharging ? .green : .red)
            .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(width: panelWidth, height: batteryHeight)
        .background(Color.black)
    }

    // MARK: - Preview Controls

    @ViewBuilder
    private var controls: some View {
        switch feature {
        case .music:
            HStack(spacing: 24) {
                Button {
                    Task {
                        await musicService.previousTrack()
                    }
                } label: {
                    Image(systemName: "backward.end.fill")
                }

                Button {
                    Task {
                        await musicService.playPause()
                    }
                } label: {
                    Image(
                        systemName: musicService.isPlaying
                            ? "pause.fill"
                            : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        await musicService.nextTrack()
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                }
            }

        case .copilot:
            Button(
                copilotNeedsPermission
                    ? "Simulate Working"
                    : "Simulate Permission Request"
            ) {
                copilotNeedsPermission.toggle()
            }

        case .safari, .appStore:
            VStack(spacing: 6) {
                Slider(value: $downloadProgress, in: 0...1)

                Text("Preview download: \(Int(downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .battery:
            HStack {
                Button("Low Battery") {
                    isCharging = false
                    batteryPercent = 18
                }

                Button("Charging") {
                    isCharging = true
                    minutesToFull = 35
                }
            }
        }
    }
}

// MARK: - Circular Download Meter

struct CircularDownloadMeter: View {
    let progress: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.white.opacity(0.2),
                    lineWidth: 3
                )

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: clampedProgress
        )
    }
}

#Preview {
    ContentView()
}
