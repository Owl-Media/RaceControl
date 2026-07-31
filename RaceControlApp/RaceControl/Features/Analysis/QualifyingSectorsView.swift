import SwiftUI
import Charts

private struct SectorWaterfallSegment: Identifiable {
    let code: String
    let sector: Int
    let start: Double
    let end: Double
    var id: String { "\(code)-\(sector)" }
}

struct QualifyingSectorsView: View {
    let year: Int
    let round: Int
    let title: String
    @StateObject private var vm = QualifyingSectorsViewModel()

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round, force: true)
        } content: { data in
            if !data.available || data.drivers.isEmpty {
                EmptyStateView(icon: "chart.bar.xaxis", title: "No Sector Data",
                               message: "No complete qualifying sector splits are available.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        Text("Sector contribution to the gap against \(data.poleCode ?? "pole"). Negative is faster.")
                            .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                        Chart {
                            RuleMark(x: .value("Pole", 0))
                                .foregroundStyle(Theme.Palette.textPrimary)
                            ForEach(vm.segments(data.drivers)) { segment in
                                BarMark(
                                    xStart: .value("Start", segment.start),
                                    xEnd: .value("End", segment.end),
                                    y: .value("Driver", segment.code)
                                )
                                .foregroundStyle(vm.color(segment.sector))
                            }
                        }
                        .chartLegend(.hidden)
                        .frame(height: CGFloat(max(330, data.drivers.count * 32)))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Qualifying sector chart")

                        ForEach(data.drivers) { driver in
                            HStack {
                                Text(driver.code).font(.headline)
                                    .foregroundStyle(Color.team(driver.teamColor))
                                Text(LapTimeFormat.format(ms: driver.lapMs, leading: true))
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Ideal \(LapTimeFormat.format(ms: driver.idealLapMs, leading: true))")
                                    Text("Gain \(Double(driver.idealGainMs) / 1000, specifier: "%.3f")s")
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                                .font(.caption)
                                if let speed = driver.speedST {
                                    Text("\(speed, specifier: "%.0f") km/h").font(.caption)
                                }
                            }
                            .padding(Theme.Space.sm)
                            .background(Theme.Palette.surfaceElevated,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        }
                    }
                    .padding(Theme.Space.md)
                }
            }
        }
        .navigationTitle("Sector Waterfall")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task { await vm.load(year: year, round: round) }
    }
}

@MainActor
final class QualifyingSectorsViewModel: ObservableObject {
    @Published var state: Loadable<QualifyingSectorsResponse> = .idle

    func load(year: Int, round: Int, force: Bool = false) async {
        if !force, case .loaded = state { return }
        state = .loading
        do {
            state = .loaded(try await APIClient.shared.qualifyingSectors(year: year, round: round))
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    fileprivate func segments(_ drivers: [QualifyingSectorDriver]) -> [SectorWaterfallSegment] {
        drivers.flatMap { driver in
            var positive = 0.0
            var negative = 0.0
            return driver.sectorDeltaMs.enumerated().map { index, raw in
                let value = Double(raw) / 1000
                let start: Double
                let end: Double
                if value >= 0 {
                    start = positive
                    positive += value
                    end = positive
                } else {
                    start = negative
                    negative += value
                    end = negative
                }
                return SectorWaterfallSegment(code: driver.code, sector: index + 1,
                                              start: start, end: end)
            }
        }
    }

    func color(_ sector: Int) -> Color {
        [Color.purple, Color.cyan, Color.orange][max(0, min(2, sector - 1))]
    }
}
