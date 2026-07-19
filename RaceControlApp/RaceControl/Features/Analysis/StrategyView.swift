import SwiftUI

/// Tyre-strategy timeline: one row per driver showing stint compounds across
/// the race distance, plus pit-stop counts.
struct StrategyView: View {
    let year: Int
    let round: Int
    let title: String

    @StateObject private var vm = StrategyViewModel()

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round)
        } content: { data in
            if data.drivers.isEmpty {
                EmptyStateView(icon: "timeline.selection", title: "No Strategy Data",
                               message: "Tyre data isn't available for this race.")
            } else {
                content(data)
            }
        }
        .navigationTitle("Tyre Strategy")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task { await vm.load(year: year, round: round) }
    }

    private func content(_ data: StrategyResponse) -> some View {
        ScrollView {
            VStack(spacing: Theme.Space.sm) {
                compoundLegend
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, Theme.Space.sm)
                ForEach(data.drivers) { driver in
                    StrategyRow(driver: driver, totalLaps: max(data.totalLaps, 1))
                }
                Text("\(data.totalLaps) laps")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.top, Theme.Space.sm)
            }
            .padding(Theme.Space.md)
        }
    }

    private var compoundLegend: some View {
        HStack(spacing: Theme.Space.md) {
            ForEach(["Soft", "Medium", "Hard", "Intermediate", "Wet"], id: \.self) { c in
                HStack(spacing: 4) {
                    Circle().fill(TyreCompound.color(c)).frame(width: 10, height: 10)
                    Text(c).font(.caption2).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StrategyRow: View {
    let driver: StrategyDriver
    let totalLaps: Int

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            VStack(alignment: .leading, spacing: 1) {
                Text(driver.code)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("\(driver.pitStops) stop\(driver.pitStops == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .frame(width: 52, alignment: .leading)

            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(driver.stints) { stint in
                        let frac = CGFloat(stint.laps) / CGFloat(totalLaps)
                        ZStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(TyreCompound.color(stint.compound))
                            if frac * geo.size.width > 26 {
                                Text("\(stint.laps)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.black.opacity(0.75))
                            }
                        }
                        .frame(width: max(frac * geo.size.width - 1, 3))
                    }
                }
            }
            .frame(height: 26)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class StrategyViewModel: ObservableObject {
    @Published var state: Loadable<StrategyResponse> = .idle

    func load(year: Int, round: Int) async {
        if case .loaded = state { return }
        state = .loading
        do {
            state = .loaded(try await APIClient.shared.strategy(year: year, round: round))
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
