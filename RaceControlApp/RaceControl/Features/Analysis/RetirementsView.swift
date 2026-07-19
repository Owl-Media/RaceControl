import SwiftUI

/// Per-race retirements / non-finishers with cause categorisation.
struct RetirementsView: View {
    let year: Int
    let round: Int
    let title: String

    @StateObject private var vm = RetirementsViewModel()

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round)
        } content: { data in
            if data.retirements.isEmpty {
                EmptyStateView(icon: "checkmark.seal.fill", title: "No Retirements",
                               message: "Every classified driver was running at the finish.")
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.sm) {
                        Text("\(data.retirements.count) driver\(data.retirements.count == 1 ? "" : "s") did not finish")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.top, Theme.Space.sm)
                        ForEach(data.retirements) { r in
                            RetirementRow(retirement: r)
                        }
                    }
                    .padding(Theme.Space.md)
                }
            }
        }
        .navigationTitle("Retirements")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task { await vm.load(year: year, round: round) }
    }
}

private struct RetirementRow: View {
    let retirement: Retirement
    private var accent: Color { .team(retirement.teamColor) }
    private var category: RetirementCategory { RetirementCategory(status: retirement.status) }

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(category.color)
                .frame(width: 32)
            TeamAccentBar(color: accent).frame(height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(retirement.fullName ?? retirement.driver ?? "Unknown")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(retirement.teamName ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            Text(retirement.status ?? "DNF")
                .font(.caption.weight(.semibold))
                .foregroundStyle(category.color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(category.color.opacity(0.15), in: Capsule())
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

enum RetirementCategory {
    case mechanical, accident, disqualified, other

    init(status: String?) {
        let s = status ?? ""
        let mech = ["Engine", "Power Unit", "Gearbox", "Hydraulics", "Transmission",
                    "Electrical", "Turbo", "Brakes", "Suspension", "Clutch", "Fuel",
                    "Cooling", "Oil", "Water", "Exhaust", "Driveshaft", "Wheel",
                    "Overheating", "Battery", "ERS", "Vibrations", "Throttle",
                    "Differential", "Mechanical", "Steering", "Radiator"]
        let coll = ["Accident", "Collision", "Spun", "Damage", "Puncture"]
        if coll.contains(where: { s.localizedCaseInsensitiveContains($0) }) { self = .accident }
        else if s == "Disqualified" { self = .disqualified }
        else if mech.contains(where: { s.localizedCaseInsensitiveContains($0) }) { self = .mechanical }
        else { self = .other }
    }

    var icon: String {
        switch self {
        case .mechanical: return "wrench.and.screwdriver.fill"
        case .accident: return "exclamationmark.triangle.fill"
        case .disqualified: return "flag.slash.fill"
        case .other: return "xmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .mechanical: return Theme.Palette.warning
        case .accident: return Theme.Palette.negative
        case .disqualified: return Theme.Palette.racingRedText
        case .other: return Theme.Palette.textSecondary
        }
    }
}

@MainActor
final class RetirementsViewModel: ObservableObject {
    @Published var state: Loadable<RetirementsResponse> = .idle

    func load(year: Int, round: Int) async {
        if case .loaded = state { return }
        state = .loading
        do {
            state = .loaded(try await APIClient.shared.retirements(year: year, round: round))
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
