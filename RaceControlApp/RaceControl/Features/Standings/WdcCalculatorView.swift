import SwiftUI

/// Drivers' championship "who can still win" calculator: for each driver still
/// in contention, shows their mathematical ceiling if they won every remaining
/// point-scoring opportunity while the current leader scored nothing else.
struct WdcCalculatorView: View {
    let year: Int
    @StateObject private var vm = WdcCalculatorViewModel()

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
    private var loadedYear: Int?

    func load(year: Int) async {
        if loadedYear == year, case .loaded = state { return }
        state = .loading
        do {
            state = .loaded(try await APIClient.shared.wdcCalculator(year: year))
            loadedYear = year
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
        // Secondary lookup for driver-detail navigation; failure shouldn't block the screen.
        if let drivers = try? await APIClient.shared.drivers(year: year) {
            driversById = Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverId, $0) })
        }
    }
}
