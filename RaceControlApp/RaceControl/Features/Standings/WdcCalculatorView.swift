import SwiftUI

/// Drivers' championship "who can still win" calculator: for each driver still
/// in contention, shows their mathematical ceiling if they won every remaining
/// point-scoring opportunity while the current leader scored nothing else.
struct WdcCalculatorView: View {
    let year: Int
    @StateObject private var vm = WdcCalculatorViewModel()
    /// Local slider position, decoupled from the network-backed
    /// `vm.selectedRound` so dragging doesn't trigger a reload on every tick.
    @State private var scrubValue: Double = 1

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year)
        } content: { data in
            content(data)
        }
        .background(Theme.Palette.background)
        .task(id: year) { await vm.load(year: year) }
    }

    private func content(_ data: WdcCalculator) -> some View {
        ScrollView {
            VStack(spacing: Theme.Space.sm) {
                timeMachineControl(data)
                statusHeader(data)
                pointsBreakdown
                LazyVStack(spacing: Theme.Space.sm) {
                    ForEach(data.drivers) { driver in
                        WdcDriverRow(driver: driver, year: year, driversById: vm.driversById)
                    }
                }
            }
            .padding(Theme.Space.md)
        }
    }

    @ViewBuilder
    private func timeMachineControl(_ data: WdcCalculator) -> some View {
        let rounds = vm.completedRounds
        if let lastRound = rounds.map(\.round).max() {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack {
                    Text("TIME MACHINE")
                        .font(.caption.weight(.bold)).tracking(1)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Spacer()
                    if vm.selectedRound != nil {
                        Button("Jump to Live") {
                            Task { await vm.load(year: year, through: nil) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.racingRed)
                    }
                }
                Text(viewingLabel(lastRound: lastRound))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Slider(
                    value: $scrubValue,
                    in: 1...Double(lastRound),
                    step: 1,
                    onEditingChanged: { editing in
                        guard !editing else { return }
                        let round = Int(scrubValue.rounded())
                        Task { await vm.load(year: year, through: round) }
                    }
                )
                .tint(Theme.Palette.racingRed)
            }
            .padding(Theme.Space.md)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Palette.stroke, lineWidth: 1))
            .onAppear {
                scrubValue = Double(vm.selectedRound ?? lastRound)
            }
        }
    }

    private func viewingLabel(lastRound: Int) -> String {
        guard let round = vm.selectedRound else {
            return "Viewing: Live standings"
        }
        if let raceName = vm.completedRounds.first(where: { $0.round == round })?.displayName {
            return "Viewing: as of Round \(round) (\(raceName))"
        }
        return "Viewing: as of Round \(round)"
    }

    @ViewBuilder
    private func statusHeader(_ data: WdcCalculator) -> some View {
        let canWinCount = data.drivers.filter(\.canWin).count
        VStack(alignment: .leading, spacing: 4) {
            Text(statusLine(data, canWinCount: canWinCount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("\u{201C}Can win\u{201D} is the best-case ceiling (winning every remaining session while the leader scores nothing else), not a realistic forecast.")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Palette.stroke, lineWidth: 1))
    }

    private func statusLine(_ data: WdcCalculator, canWinCount: Int) -> String {
        if data.decided && data.roundsRemaining == 0 {
            return "Season complete: the title is decided."
        }
        if data.decided {
            return "Mathematically settled: only the leader can still win."
        }
        let roundWord = data.roundsRemaining == 1 ? "round" : "rounds"
        let driverWord = canWinCount == 1 ? "driver" : "drivers"
        return "\(data.roundsRemaining) \(roundWord) left · up to \(data.maxRemainingPoints) points still on offer · \(canWinCount) \(driverWord) can still win"
    }

    private var pointsBreakdown: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Race (P1–P10): 25, 18, 15, 12, 10, 8, 6, 4, 2, 1")
                Text("Sprint (P1–P8): 8, 7, 6, 5, 4, 3, 2, 1")
                Text("Fastest lap bonus: +1 (top 10 finishers, race only)")
            }
            .font(.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
            .padding(.top, Theme.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("POINTS BREAKDOWN")
                .font(.caption.weight(.bold)).tracking(1)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Palette.stroke, lineWidth: 1))
    }
}

private struct WdcDriverRow: View {
    let driver: WdcDriverEntry
    let year: Int
    let driversById: [String: Driver]

    private var matchedDriver: Driver? {
        guard let id = driver.driverId else { return nil }
        return driversById[id]
    }

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            PositionBadge(text: String(driver.position ?? 0), highlight: (driver.position ?? 0) <= 3)
            TeamAccentBar(color: .team(driver.teamColor))
            TeamLogoView(url: driver.teamLogoUrl, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                nameLabel
                Text(driver.teamName ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(numberLabel(driver.points))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("PTS").font(.caption2).foregroundStyle(Theme.Palette.textTertiary)
                    }
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(behindLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(driver.pointsBehindLeader == 0 ? Theme.Palette.positive : Theme.Palette.textSecondary)
                        Text("MAX \(numberLabel(driver.maxPoints))")
                            .font(.caption2)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                canWinPill
            }
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Palette.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private var nameLabel: some View {
        if let matchedDriver {
            NavigationLink {
                DriverDetailView(year: year, driver: matchedDriver)
            } label: {
                Text(driver.fullName)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
            }
        } else {
            Text(driver.fullName)
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)
        }
    }

    private var behindLabel: String {
        driver.pointsBehindLeader == 0 ? "Leader" : "-\(numberLabel(driver.pointsBehindLeader))"
    }

    private var canWinPill: some View {
        Text(driver.canWin ? "Can win" : "Can't win")
            .font(.caption2.weight(.bold))
            .foregroundStyle(driver.canWin ? Theme.Palette.positive : Theme.Palette.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                (driver.canWin ? Theme.Palette.positive : Theme.Palette.textTertiary).opacity(0.15),
                in: Capsule()
            )
    }

    private func numberLabel(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

@MainActor
final class WdcCalculatorViewModel: ObservableObject {
    @Published var state: Loadable<WdcCalculator> = .idle
    @Published var driversById: [String: Driver] = [:]
    /// Completed events for the season, sorted by round, used to build the
    /// time-machine scrubber's valid range and race-name labels.
    @Published var completedRounds: [RaceEvent] = []
    /// nil = live standings. Non-nil = viewing the calculator as it stood at
    /// the end of that round.
    @Published var selectedRound: Int? = nil
    private var loadedYear: Int?
    /// Wrapped so we can distinguish "never loaded" (nil) from "loaded for
    /// live standings" (Optional(nil)).
    private var loadedRound: Int?? = nil
    /// Tracks which year we've already fired the background cache warm-up
    /// for, so it only happens once per year rather than on every reload.
    private var warmedYear: Int?

    func load(year: Int) async {
        await load(year: year, through: selectedRound)
    }

    func load(year: Int, through round: Int?) async {
        if loadedYear == year, loadedRound == Optional(round), case .loaded = state { return }
        state = .loading
        selectedRound = round
        do {
            state = .loaded(try await APIClient.shared.wdcCalculator(year: year, throughRound: round))
            loadedYear = year
            loadedRound = round
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
        // Secondary lookups for driver-detail navigation and the round
        // scrubber; failure shouldn't block the main screen.
        if let drivers = try? await APIClient.shared.drivers(year: year) {
            driversById = Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverId, $0) })
        }
        if let schedule = try? await APIClient.shared.schedule(year: year) {
            completedRounds = schedule.filter(\.completed).sorted { $0.round < $1.round }
        }
        warmTimeMachineCache(year: year)
    }

    /// Fires a background, best-effort request for a historical round as
    /// soon as we know the season has one, so the backend's shared
    /// per-season computation happens during page load instead of during
    /// the user's first slider drag. The backend caches that computation per
    /// year regardless of which round is requested, so warming any single
    /// round makes the *entire* scrubber fast, not just that one round. This
    /// result is discarded, it's purely to warm the server-side cache.
    private func warmTimeMachineCache(year: Int) {
        guard warmedYear != year, let lastRound = completedRounds.last?.round else { return }
        warmedYear = year
        Task.detached {
            _ = try? await APIClient.shared.wdcCalculator(year: year, throughRound: lastRound)
        }
    }
}
