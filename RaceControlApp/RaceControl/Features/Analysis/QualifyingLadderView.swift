import SwiftUI
import Charts

/// Q1 -> Q2 -> Q3 as narrowing lanes: each driver's gap to the segment's
/// best time, carried forward until elimination. The shape of the lines
/// tells the session story before a number is read.
struct QualifyingLadderView: View {
    let year: Int
    let round: Int
    let title: String

    @StateObject private var vm = QualifyingLadderViewModel()

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round)
        } content: { data in
            if data.isEmpty {
                EmptyStateView(icon: "stopwatch", title: "No Qualifying Data",
                               message: "No qualifying session times are available for this race.")
            } else {
                content(data)
            }
        }
        .navigationTitle("Qualifying Ladder")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task(id: "\(year)-\(round)") { await vm.load(year: year, round: round) }
    }

    private func content(_ data: [LadderDriver]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text("Gap to session best · lower is slower · line ends at elimination")
                    .font(.caption).foregroundStyle(Theme.Palette.textSecondary)

                Chart {
                    ForEach(data) { driver in
                        ForEach(driver.points) { point in
                            LineMark(x: .value("Segment", Double(point.column)), y: .value("Gap", point.value))
                                .foregroundStyle(Color.team(driver.teamColor))
                                .interpolationMethod(.monotone)
                        }
                        ForEach(driver.points) { point in
                            PointMark(x: .value("Segment", Double(point.column)), y: .value("Gap", point.value))
                                .foregroundStyle(Color.team(driver.teamColor))
                        }
                        if let last = driver.points.last {
                            PointMark(x: .value("Segment", Double(last.column)), y: .value("Gap", last.value))
                                .foregroundStyle(.clear)
                                .annotation(position: .trailing) {
                                    Text("\(driver.code)\(driver.suffix)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.team(driver.teamColor))
                                }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXScale(domain: 0.5...3.7)
                .chartXAxis {
                    AxisMarks(values: [1.0, 2.0, 3.0]) { value in
                        AxisGridLine().foregroundStyle(Theme.Palette.stroke)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("Q\(Int(v))").font(.caption2.weight(.bold))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.Palette.stroke); AxisValueLabel().font(.caption2)
                    }
                }
                .frame(height: 340)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Qualifying ladder chart")
                .padding(.trailing, 46) // room for trailing driver-code labels
            }
            .padding(Theme.Space.md)
        }
    }
}

// MARK: - View model

struct LadderPoint: Identifiable {
    let column: Int // 1 = Q1, 2 = Q2, 3 = Q3
    let value: Double // seconds behind that segment's best
    var id: Int { column }
}

struct LadderDriver: Identifiable {
    let code: String
    let teamColor: String?
    let points: [LadderPoint]
    let finalPosition: Int?
    let eliminatedAfter: Int? // 1 or 2, nil if reached/survived Q3

    var id: String { code }
    var suffix: String {
        if let eliminatedAfter { return " · out Q\(eliminatedAfter)" }
        if let finalPosition { return " · P\(finalPosition)" }
        return ""
    }
}

@MainActor
final class QualifyingLadderViewModel: ObservableObject {
    @Published var state: Loadable<[LadderDriver]> = .idle
    private var loadedKey: String?

    func load(year: Int, round: Int) async {
        let key = "\(year)-\(round)"
        if loadedKey == key, case .loaded = state { return }
        state = .loading
        do {
            let response = try await APIClient.shared.results(year: year, round: round, session: "Q")
            let rows = response.results

            let q1Times = rows.compactMap { Self.seconds(from: $0.q1) }
            let q2Times = rows.compactMap { Self.seconds(from: $0.q2) }
            let q3Times = rows.compactMap { Self.seconds(from: $0.q3) }
            let bestQ1 = q1Times.min()
            let bestQ2 = q2Times.min()
            let bestQ3 = q3Times.min()

            let drivers: [LadderDriver] = rows.compactMap { row in
                var points: [LadderPoint] = []
                if let t = Self.seconds(from: row.q1), let best = bestQ1 {
                    points.append(LadderPoint(column: 1, value: t - best))
                }
                if let t = Self.seconds(from: row.q2), let best = bestQ2 {
                    points.append(LadderPoint(column: 2, value: t - best))
                }
                if let t = Self.seconds(from: row.q3), let best = bestQ3 {
                    points.append(LadderPoint(column: 3, value: t - best))
                }
                guard !points.isEmpty, let code = row.abbreviation else { return nil }
                let eliminatedAfter: Int? = points.count < 3 ? points.last?.column : nil
                let finalPosition = points.count == 3 ? row.position.map { Int($0) } : nil
                return LadderDriver(code: code, teamColor: row.teamColor, points: points,
                                     finalPosition: finalPosition, eliminatedAfter: eliminatedAfter)
            }
            state = .loaded(drivers)
            loadedKey = key
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Parses a "m:ss.mmm" lap-time string into seconds.
    private static func seconds(from text: String?) -> Double? {
        guard let text, !text.isEmpty else { return nil }
        let parts = text.split(separator: ":")
        if parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) {
            return minutes * 60 + seconds
        }
        return Double(text)
    }
}
