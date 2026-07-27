import SwiftUI

/// Season reliability: finish rate and DNF breakdown (mechanical / accident /
/// disqualified / other) per driver and per team.
struct ReliabilityView: View {
    let year: Int
    @StateObject private var vm = ReliabilityViewModel()
    @State private var mode: Mode = .drivers

    enum Mode: String, CaseIterable { case drivers = "Drivers", teams = "Teams" }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Space.md)
            .padding(.bottom, Theme.Space.sm)

            LoadableView(state: vm.state) {
                await vm.load(year: year)
            } content: { data in
                ScrollView {
                    VStack(spacing: Theme.Space.sm) {
                        legend
                        if mode == .drivers {
                            ForEach(data.drivers) { d in
                                ReliabilityRow(title: d.name, subtitle: nil,
                                               finished: d.finished, mechanical: d.mechanical,
                                               accident: d.accident, disqualified: d.disqualified,
                                               other: d.other, starts: d.starts, finishRate: d.finishRate)
                            }
                        } else {
                            ForEach(data.teams) { t in
                                ReliabilityRow(title: t.teamName ?? t.teamId, subtitle: nil,
                                               finished: t.finished, mechanical: t.mechanical,
                                               accident: t.accident, disqualified: t.disqualified,
                                               other: t.other, starts: t.starts, finishRate: t.finishRate,
                                               logoUrl: t.teamLogoUrl)
                            }
                        }
                    }
                    .padding(Theme.Space.md)
                }
            }
        }
        .background(Theme.Palette.background)
        .task(id: year) { await vm.load(year: year) }
    }

    private var legend: some View {
        HStack(spacing: Theme.Space.md) {
            legendItem("Finished", Theme.Palette.positive)
            legendItem("Mechanical", Theme.Palette.warning)
            legendItem("Accident", Theme.Palette.negative)
            legendItem("Other", Theme.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(Theme.Palette.textSecondary)
        }
    }
}

private struct ReliabilityRow: View {
    let title: String
    let subtitle: String?
    let finished: Int
    let mechanical: Int
    let accident: Int
    let disqualified: Int
    let other: Int
    let starts: Int
    let finishRate: Double
    var logoUrl: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                TeamLogoView(url: logoUrl, size: 20)
                Text(title)
                    .font(.headline).foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
                Spacer()
                Text("\(Int(finishRate))%")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(finishColor)
                Text("finished").font(.caption2).foregroundStyle(Theme.Palette.textTertiary)
            }
            // Stacked reliability bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    segment(finished, Theme.Palette.positive, geo.size.width)
                    segment(mechanical, Theme.Palette.warning, geo.size.width)
                    segment(accident, Theme.Palette.negative, geo.size.width)
                    segment(disqualified + other, Theme.Palette.textTertiary, geo.size.width)
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())

            HStack(spacing: Theme.Space.md) {
                if mechanical > 0 { tag("\(mechanical) mech", Theme.Palette.warning) }
                if accident > 0 { tag("\(accident) crash", Theme.Palette.negative) }
                if disqualified > 0 { tag("\(disqualified) DSQ", Theme.Palette.racingRedText) }
                Spacer()
                Text("\(starts) starts").font(.caption2).foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Palette.stroke, lineWidth: 1))
    }

    private func segment(_ count: Int, _ color: Color, _ width: CGFloat) -> some View {
        Rectangle().fill(color)
            .frame(width: starts > 0 ? max(width * CGFloat(count) / CGFloat(starts), count > 0 ? 3 : 0) : 0)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.semibold)).foregroundStyle(color)
    }

    private var finishColor: Color {
        finishRate >= 90 ? Theme.Palette.positive : finishRate >= 75 ? Theme.Palette.warning : Theme.Palette.negative
    }
}

@MainActor
final class ReliabilityViewModel: ObservableObject {
    @Published var state: Loadable<ReliabilityResponse> = .idle
    private var loadedYear: Int?

    func load(year: Int) async {
        if loadedYear == year, case .loaded = state { return }
        state = .loading
        do {
            state = .loaded(try await APIClient.shared.reliability(year: year))
            loadedYear = year
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
