import SwiftUI

/// Lap-by-lap race replay. The running order animates as you scrub or play
/// through the laps — an at-a-glance re-watch of how the race unfolded.
struct ReplayView: View {
    let year: Int
    let round: Int
    let title: String

    @StateObject private var vm = ReplayViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round)
        } content: { replay in
            content(replay)
        }
        .navigationTitle("Replay")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task { await vm.load(year: year, round: round) }
        .onDisappear { vm.stop() }
    }

    @ViewBuilder
    private func content(_ replay: RaceReplay) -> some View {
        if replay.frames.isEmpty {
            EmptyStateView(icon: "play.slash", title: "No Replay Data",
                           message: "Lap timing isn't available for this race.")
        } else {
            VStack(spacing: 0) {
                lapHeader(replay)
                orderList(replay)
                controls(replay)
            }
        }
    }

    private func lapHeader(_ replay: RaceReplay) -> some View {
        VStack(spacing: 2) {
            Text(replay.eventName ?? title)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("LAP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text("\(vm.currentLap)")
                    // Semantic style so the lap counter scales with Dynamic Type.
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                Text("/ \(replay.totalLaps)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(.top, Theme.Space.md)
    }

    private func orderList(_ replay: RaceReplay) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(vm.frame?.order ?? []) { entry in
                    ReplayRow(entry: entry, previousPosition: vm.previousPosition(for: entry.driver))
                        .transition(.opacity)
                }
            }
            .padding(Theme.Space.md)
            // Position changes animate as cars swap places — unless the user
            // has asked the system to reduce motion.
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
                       value: vm.currentLap)
        }
    }

    private func controls(_ replay: RaceReplay) -> some View {
        VStack(spacing: Theme.Space.sm) {
            Slider(
                value: Binding(
                    get: { Double(vm.currentLap) },
                    set: { vm.scrub(to: Int($0.rounded())) }
                ),
                in: 1...Double(max(replay.totalLaps, 1)),
                step: 1
            )
            .tint(Theme.Palette.racingRed)

            HStack(spacing: Theme.Space.xl) {
                controlButton("backward.end.fill", label: "Back to first lap") { vm.scrub(to: 1) }
                controlButton("gobackward.5", label: "Back 5 laps") { vm.scrub(to: vm.currentLap - 5) }
                Button {
                    vm.togglePlay()
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.Palette.racingRed)
                }
                .accessibilityLabel(vm.isPlaying ? "Pause replay" : "Play replay")
                controlButton("goforward.5", label: "Forward 5 laps") { vm.scrub(to: vm.currentLap + 5) }
                controlButton("forward.end.fill", label: "Skip to final lap") { vm.scrub(to: replay.totalLaps) }
            }
            .accessibilityElement(children: .contain)

            // Playback speed
            Picker("Speed", selection: $vm.speed) {
                Text("0.5×").tag(0.5)
                Text("1×").tag(1.0)
                Text("2×").tag(2.0)
                Text("4×").tag(4.0)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Space.lg)
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.surface)
    }

    private func controlButton(_ system: String, label: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title3)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: Theme.minTouch, height: Theme.minTouch)
        }
        .accessibilityLabel(label)
    }
}

private struct ReplayRow: View {
    let entry: ReplayEntry
    let previousPosition: Int?

    private var accent: Color { .team(entry.teamColor) }
    private var movement: Int? {
        guard let prev = previousPosition else { return nil }
        return prev - entry.position // positive = moved up
    }

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Text("\(entry.position)")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 30)

            movementIndicator

            TeamAccentBar(color: accent).frame(height: 28)

            Text(entry.driver)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 48, alignment: .leading)

            TeamLogoView(url: entry.teamLogoUrl, size: 18)

            Text(entry.teamName ?? "")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if entry.compound != nil {
                TyreBadge(compound: entry.compound, size: 22)
            }
            if let lap = entry.lapTime {
                Text(lap)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(width: 66, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, Theme.Space.sm)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    @ViewBuilder private var movementIndicator: some View {
        Group {
            if let m = movement, m > 0 {
                Image(systemName: "arrowtriangle.up.fill").foregroundStyle(Theme.Palette.positive)
            } else if let m = movement, m < 0 {
                Image(systemName: "arrowtriangle.down.fill").foregroundStyle(Theme.Palette.negative)
            } else {
                Image(systemName: "minus").foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .font(.caption2)
        .frame(width: 12)
    }
}

@MainActor
final class ReplayViewModel: ObservableObject {
    @Published var state: Loadable<RaceReplay> = .idle
    @Published var currentLap: Int = 1
    @Published var isPlaying = false
    @Published var speed: Double = 1.0 {
        didSet { if isPlaying { restartTimer() } }
    }

    private var replay: RaceReplay?
    private var framesByLap: [Int: ReplayFrame] = [:]
    private var timer: Timer?

    var frame: ReplayFrame? { framesByLap[currentLap] ?? nearestFrame() }

    func load(year: Int, round: Int) async {
        if case .loaded = state { return }
        state = .loading
        do {
            let data = try await APIClient.shared.replay(year: year, round: round)
            replay = data
            framesByLap = Dictionary(uniqueKeysWithValues: data.frames.map { ($0.lap, $0) })
            currentLap = data.frames.first?.lap ?? 1
            state = .loaded(data)
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func previousPosition(for driver: String) -> Int? {
        guard currentLap > 1 else { return nil }
        let prev = framesByLap[currentLap - 1] ?? framesByLap.filter { $0.key < currentLap }.max(by: { $0.key < $1.key })?.value
        return prev?.order.first(where: { $0.driver == driver })?.position
    }

    func scrub(to lap: Int) {
        guard let replay else { return }
        currentLap = min(max(lap, 1), replay.totalLaps)
    }

    func togglePlay() {
        Haptics.impact(.medium)
        isPlaying ? stop() : play()
    }

    private func play() {
        guard let replay else { return }
        if currentLap >= replay.totalLaps { currentLap = 1 }
        isPlaying = true
        restartTimer()
    }

    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func restartTimer() {
        timer?.invalidate()
        let interval = 0.9 / speed
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
    }

    private func advance() {
        guard let replay else { return }
        if currentLap < replay.totalLaps {
            currentLap += 1
        } else {
            stop()
        }
    }

    private func nearestFrame() -> ReplayFrame? {
        framesByLap.filter { $0.key <= currentLap }.max(by: { $0.key < $1.key })?.value
            ?? framesByLap.min(by: { $0.key < $1.key })?.value
    }
}
