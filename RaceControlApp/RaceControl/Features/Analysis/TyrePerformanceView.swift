import SwiftUI
import Charts

struct TyrePerformanceView: View {
    let year: Int
    let round: Int
    let title: String

    @StateObject private var vm = TyrePerformanceViewModel()

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round, force: true)
        } content: { data in
            if !data.available || data.stints.isEmpty {
                EmptyStateView(icon: "circle.dashed", title: "No Tyre Data",
                               message: "No clean stints are available for degradation analysis.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        Chart {
                            ForEach(vm.visible(data.stints)) { stint in
                                ForEach(stint.points, id: \.lap) { point in
                                    PointMark(
                                        x: .value("Tyre life", point.tyreLife),
                                        y: .value("Delta", Double(point.deltaMs) / 1000)
                                    )
                                    .foregroundStyle(TyreCompound.color(stint.compound))
                                    .symbolSize(35)
                                }
                                ForEach(stint.fit, id: \.tyreLife) { point in
                                    LineMark(
                                        x: .value("Tyre life", point.tyreLife),
                                        y: .value("Fit", Double(point.deltaMs) / 1000),
                                        series: .value("Stint", stint.id)
                                    )
                                    .foregroundStyle(TyreCompound.color(stint.compound))
                                    .lineStyle(.init(lineWidth: 1.5, dash: [5, 3]))
                                }
                            }
                        }
                        .chartLegend(.hidden)
                        .frame(height: 340)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Tyre performance chart")

                        Picker("Compound", selection: $vm.compound) {
                            Text("All").tag("ALL")
                            ForEach(vm.compounds(data.stints), id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        ForEach(data.compoundBaselines) { baseline in
                            HStack {
                                Circle().fill(TyreCompound.color(baseline.compound))
                                    .frame(width: 10, height: 10)
                                Text(baseline.compound)
                                Spacer()
                                Text(String(format: "%.3f s/lap median", baseline.slopeSecPerLap))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            .font(.footnote)
                        }
                    }
                    .padding(Theme.Space.md)
                }
            }
        }
        .navigationTitle("Tyre Degradation")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task { await vm.load(year: year, round: round) }
    }
}

@MainActor
final class TyrePerformanceViewModel: ObservableObject {
    @Published var state: Loadable<TyrePerformanceResponse> = .idle
    @Published var compound = "ALL"

    func load(year: Int, round: Int, force: Bool = false) async {
        if !force, case .loaded = state { return }
        state = .loading
        do {
            state = .loaded(try await APIClient.shared.tyrePerformance(year: year, round: round))
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func compounds(_ stints: [TyrePerformanceStint]) -> [String] {
        Array(Set(stints.compactMap { $0.compound?.uppercased() })).sorted()
    }

    func visible(_ stints: [TyrePerformanceStint]) -> [TyrePerformanceStint] {
        compound == "ALL" ? stints : stints.filter { $0.compound?.uppercased() == compound }
    }
}
