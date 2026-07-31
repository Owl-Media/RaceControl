import SwiftUI
import Charts

/// Shared-scale dot plot of the four speed-trap detection points (I1, I2,
/// FL, ST), one row per driver. Exposes setup tradeoffs — low-drag top
/// speed vs. cornering compromise — that lap time and sector gaps alone
/// hide, and shows tow effects at a glance.
struct SpeedTrapView: View {
    let year: Int
    let round: Int
    let title: String

    @StateObject private var vm = SpeedTrapViewModel()

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round)
        } content: { data in
            if data.isEmpty {
                EmptyStateView(icon: "speedometer", title: "No Speed-Trap Data",
                               message: "No qualifying speed-trap readings are available for this session.")
            } else {
                content(data)
            }
        }
        .navigationTitle("Speed Trap")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task(id: "\(year)-\(round)") { await vm.load(year: year, round: round) }
    }

    private func content(_ data: [SpeedTrapDriver]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text("Speed at each detection point · km/h")
                    .font(.caption).foregroundStyle(Theme.Palette.textSecondary)

                Chart {
                    ForEach(data) { driver in
                        ForEach(driver.points) { point in
                            LineMark(x: .value("Speed", point.speed), y: .value("Driver", driver.code))
                                .foregroundStyle(Color.team(driver.teamColor).opacity(0.6))
                        }
                        ForEach(driver.points) { point in
                            PointMark(x: .value("Speed", point.speed), y: .value("Driver", driver.code))
                                .foregroundStyle(Color.team(driver.teamColor))
                                .symbolSize(point.label == "ST" ? 90 : 40)
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.Palette.stroke); AxisValueLabel().font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().font(.caption2.weight(.bold)) }
                }
                .frame(height: CGFloat(max(280, data.count * 34)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Speed trap chart")

                legend
            }
            .padding(Theme.Space.md)
        }
    }

    private var legend: some View {
        HStack(spacing: Theme.Space.md) {
            Text("I1 / I2 / FL").font(.caption2).foregroundStyle(Theme.Palette.textSecondary)
            HStack(spacing: 4) {
                Circle().fill(Theme.Palette.textSecondary).frame(width: 10, height: 10)
                Text("ST emphasized").font(.caption2).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }
}

// MARK: - View model

struct SpeedTrapPoint: Identifiable {
    let label: String
    let speed: Double
    var id: String { label }
}

struct SpeedTrapDriver: Identifiable {
    let code: String
    let teamColor: String?
    let points: [SpeedTrapPoint]
    var id: String { code }
}

@MainActor
final class SpeedTrapViewModel: ObservableObject {
    @Published var state: Loadable<[SpeedTrapDriver]> = .idle
    private var loadedKey: String?

    func load(year: Int, round: Int) async {
        let key = "\(year)-\(round)"
        if loadedKey == key, case .loaded = state { return }
        state = .loading
        do {
            let response = try await APIClient.shared.qualifyingSectors(year: year, round: round)
            let drivers = response.drivers.compactMap { driver -> SpeedTrapDriver? in
                guard let i1 = driver.speedI1, let i2 = driver.speedI2,
                      let fl = driver.speedFL, let st = driver.speedST else { return nil }
                return SpeedTrapDriver(
                    code: driver.code,
                    teamColor: driver.teamColor,
                    points: [
                        SpeedTrapPoint(label: "I1", speed: i1),
                        SpeedTrapPoint(label: "I2", speed: i2),
                        SpeedTrapPoint(label: "FL", speed: fl),
                        SpeedTrapPoint(label: "ST", speed: st),
                    ]
                )
            }.sorted { ($0.points.last?.speed ?? 0) > ($1.points.last?.speed ?? 0) }
            state = .loaded(drivers)
            loadedKey = key
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
