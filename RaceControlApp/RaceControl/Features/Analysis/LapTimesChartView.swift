import SwiftUI
import Charts

/// Lap-time evolution: a multi-driver line chart of lap times through the race.
struct LapTimesChartView: View {
    let year: Int
    let round: Int
    let title: String

    @StateObject private var vm = LapTimesViewModel()

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round)
        } content: { data in
            if data.drivers.isEmpty {
                EmptyStateView(icon: "chart.xyaxis.line", title: "No Lap Data",
                               message: "Lap timing isn't available for this race.")
            } else {
                content(data)
            }
        }
        .navigationTitle("Lap Times")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task { await vm.load(year: year, round: round) }
    }

    private func content(_ data: LapTimesResponse) -> some View {
        VStack(spacing: Theme.Space.sm) {
            chart(data)
                .padding(Theme.Space.md)

            HStack {
                Toggle("Hide outliers", isOn: $vm.hideOutliers)
                    .font(.footnote)
                    .tint(Theme.Palette.racingRed)
                Spacer()
                Button("All") { vm.selectAll(data.drivers) }
                    .font(.footnote.weight(.semibold))
                Button("None") { vm.selected.removeAll() }
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, Theme.Space.md)

            driverChips(data.drivers)
        }
    }

    private func chart(_ data: LapTimesResponse) -> some View {
        let drivers = data.drivers.filter { vm.selected.contains($0.code) }
        let domain = vm.yDomain(for: drivers)
        return Chart {
            ForEach(drivers) { driver in
                ForEach(vm.visibleLaps(driver), id: \.lap) { lp in
                    LineMark(
                        x: .value("Lap", lp.lap),
                        y: .value("Time", lp.seconds)
                    )
                    .foregroundStyle(Color.team(driver.teamColor))
                    .foregroundStyle(by: .value("Driver", driver.code))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartForegroundStyleScale(domain: drivers.map(\.code),
                                   range: drivers.map { Color.team($0.teamColor) })
        .chartLegend(.hidden)
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Theme.Palette.stroke)
                AxisValueLabel {
                    if let s = value.as(Double.self) {
                        Text(LapFormat.secondsToLap(s))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.Palette.stroke)
                AxisValueLabel().font(.caption2)
            }
        }
        .frame(height: 320)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lap time chart")
        .accessibilityValue(drivers.isEmpty
            ? "No drivers selected"
            : "Lap times for \(drivers.map(\.code).joined(separator: ", ")) across \(data.totalLaps) laps")
        .overlay {
            if drivers.isEmpty {
                Text("Select drivers below to plot their lap times.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }

    private func driverChips(_ drivers: [LapTimeDriver]) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: Theme.Space.sm)],
                      spacing: Theme.Space.sm) {
                ForEach(drivers) { d in
                    let on = vm.selected.contains(d.code)
                    Button { vm.toggle(d.code) } label: {
                        Text(d.code)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(on ? Color.black : Theme.Palette.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                            .background(on ? Color.team(d.teamColor) : Theme.Palette.surfaceElevated,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.team(d.teamColor), lineWidth: on ? 0 : 1.5))
                    }
                    .accessibilityLabel(d.code)
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(Theme.Space.md)
        }
    }
}

@MainActor
final class LapTimesViewModel: ObservableObject {
    @Published var state: Loadable<LapTimesResponse> = .idle
    @Published var selected: Set<String> = []
    @Published var hideOutliers = true

    func load(year: Int, round: Int) async {
        if case .loaded = state { return }
        state = .loading
        do {
            let data = try await APIClient.shared.lapTimes(year: year, round: round)
            // Preselect the first few drivers so the chart isn't empty.
            selected = Set(data.drivers.prefix(5).map(\.code))
            state = .loaded(data)
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func toggle(_ code: String) {
        Haptics.selection()
        if selected.contains(code) { selected.remove(code) } else { selected.insert(code) }
    }
    func selectAll(_ drivers: [LapTimeDriver]) { selected = Set(drivers.map(\.code)) }

    /// Filter out pit/safety-car laps that would blow up the y-axis.
    func visibleLaps(_ driver: LapTimeDriver) -> [LapTimePoint] {
        guard hideOutliers else { return driver.laps }
        let times = driver.laps.map(\.seconds).sorted()
        guard let median = times.middle else { return driver.laps }
        let cutoff = median * 1.10
        return driver.laps.filter { $0.seconds <= cutoff }
    }

    func yDomain(for drivers: [LapTimeDriver]) -> ClosedRange<Double> {
        let all = drivers.flatMap { visibleLaps($0).map(\.seconds) }
        guard let lo = all.min(), let hi = all.max(), lo < hi else { return 0...1 }
        let pad = (hi - lo) * 0.05
        return (lo - pad)...(hi + pad)
    }
}

private extension Array where Element == Double {
    var middle: Double? { isEmpty ? nil : self[count / 2] }
}

enum LapFormat {
    static func secondsToLap(_ s: Double) -> String {
        guard s > 0 else { return "—" }
        let minutes = Int(s) / 60
        let seconds = s - Double(minutes * 60)
        return minutes > 0 ? String(format: "%d:%06.3f", minutes, seconds)
                           : String(format: "%.3f", seconds)
    }

    /// Parse a "m:ss.mmm" or "ss.mmm" lap string into seconds.
    static func lapToSeconds(_ text: String?) -> Double? {
        guard let text, !text.isEmpty, text != "—" else { return nil }
        let parts = text.split(separator: ":")
        if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
            return m * 60 + s
        }
        return Double(text)
    }
}
