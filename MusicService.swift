
import AppKit
import Foundation
import Combine

@MainActor
final class MusicService: ObservableObject {

    @Published var title = ""
    @Published var artist = ""
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var artwork: NSImage?
    @Published var errorMessage: String?

    var hasTrack: Bool {
        !title.isEmpty
    }

    private var pollingTimer: Timer?
    private var lastArtworkTrack = ""

    // MARK: - Polling

    func startPolling() {
        guard pollingTimer == nil else { return }

        refreshMusicStatus()

        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMusicStatus()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func refresh() async {
        refreshMusicStatus()
    }

    // MARK: - Read Music Status

    private func refreshMusicStatus() {
        let script = """
        tell application "Music"
            set trackName to ""
            set artistName to ""
            set stateName to "stopped"
            set trackDuration to 0
            set trackPosition to 0

            try
                set stateName to player state as string

                if stateName is "playing" or stateName is "paused" then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set trackDuration to duration of current track
                    set trackPosition to player position
                end if
            end try

            return trackName & "||" & artistName & "||" & stateName & "||" & trackDuration & "||" & trackPosition
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            errorMessage = "Unable to create the Apple Music script."
            return
        }

        var scriptError: NSDictionary?
        let result = appleScript.executeAndReturnError(&scriptError)

        if let scriptError {
            errorMessage =
                scriptError[NSAppleScript.errorMessage] as? String
                ?? "Could not communicate with Apple Music."
            return
        }

        guard let output = result.stringValue else {
            errorMessage = "Apple Music returned no information."
            return
        }

        let values = output.components(separatedBy: "||")

        guard values.count >= 5 else {
            errorMessage = "Unexpected Apple Music response."
            return
        }

        let newTitle = values[0]
        let newArtist = values[1]
        let newState = values[2].lowercased()
        let newDuration = Double(values[3]) ?? 0
        let newTime = Double(values[4]) ?? 0

        let trackChanged =
            newTitle != title || newArtist != artist

        title = newTitle
        artist = newArtist
        isPlaying = newState == "playing"
        duration = max(0, newDuration)
        currentTime = max(0, newTime)
        errorMessage = nil

        if trackChanged {
            artwork = nil
            lastArtworkTrack = ""

            if !newTitle.isEmpty {
                artwork = fetchArtwork()
                lastArtworkTrack = newTitle + "||" + newArtist
            }
        } else if artwork == nil && !newTitle.isEmpty {
            let trackKey = newTitle + "||" + newArtist

            if lastArtworkTrack != trackKey {
                artwork = fetchArtwork()
                lastArtworkTrack = trackKey
            }
        }
    }

    // MARK: - Album Artwork

    private func fetchArtwork() -> NSImage? {
        let script = """
        tell application "Music"
            try
                if player state is playing or player state is paused then
                    return data of artwork 1 of current track
                end if
            end try
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        var scriptError: NSDictionary?
        let result = appleScript.executeAndReturnError(&scriptError)

        guard scriptError == nil else {
            return nil
        }

        let imageData = result.data

        guard !imageData.isEmpty else {
            return nil
        }

        return NSImage(data: imageData)
    }

    // MARK: - Playback Controls

    func playPause() async {
        runMusicCommand("playpause")
    }

    func nextTrack() async {
        runMusicCommand("next track")
    }

    func previousTrack() async {
        runMusicCommand("previous track")
    }

    private func runMusicCommand(_ command: String) {
        let script = """
        tell application "Music"
            \(command)
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            errorMessage = "Unable to create playback command."
            return
        }

        var scriptError: NSDictionary?
        appleScript.executeAndReturnError(&scriptError)

        if let scriptError {
            errorMessage =
                scriptError[NSAppleScript.errorMessage] as? String
                ?? "Playback command failed."
        } else {
            refreshMusicStatus()
        }
    }
}
