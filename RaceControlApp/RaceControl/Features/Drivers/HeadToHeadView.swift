import SwiftUI

/// Head-to-head: pick two drivers and compare their season — points, wins,
/// podiums, poles, best finish, DNFs, and direct qualifying/race records.
struct HeadToHeadView: View {
    let year: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = HeadToHeadViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.md) {
                    slots
                    driverPicker
                    results
                }
                .padding(Theme.Space.md)
            }
            .background(Theme.Palette.background)
            .navigationTitle("Head to Head")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await vm.loadDrivers(year: year) }
        }
    }

    // MARK: Selected slots
    private var slots: some View {
        HStack(spacing: Theme.Space.sm) {
            slot(vm.driver1, accent: Theme.Palette.racingRed, placeholder: "Driver 1")
            Text("VS").font(.caption.weight(.black)).foregroundStyle(Theme.Palette.textTertiary)
            slot(vm.driver2, accent: Theme.Palette.info, placeholder: "Driver 2")
        }
    }

    private func slot(_ driver: Driver?, accent: Color, placeholder: String) -> some View {
        VStack(spacing: 4) {
            DriverAvatar(url: driver?.headshotUrl, initials: driver?.code ?? "?",
                         accent: accent, size: 56)
            Text(driver?.code ?? placeholder)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(driver?.teamName ?? "Tap a driver below")
                .font(.caption2).foregroundStyle(Theme.Palette.textSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.sm)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(accent.opacity(0.5), lineWidth: 1))
    }

    // MARK: Driver picker (chips)
    @ViewBuilder private var driverPicker: some View {
        if vm.loadingDrivers {
            ProgressView().tint(Theme.Palette.racingRed).frame(height: 60)
        } else if vm.drivers.isEmpty {
            Text("Couldn't load drivers for \(String(year)).")
                .font(.subheadline).foregroundStyle(Theme.Palette.textSecondary)
                .frame(maxWidth: .infinity).padding(.vertical, Theme.Space.md)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: Theme.Space.sm)],
                      spacing: Theme.Space.sm) {
                ForEach(vm.drivers) { d in
                    driverChip(d)
                }
            }
        }
    }

    private func driverChip(_ d: Driver) -> some View {
        let slot = vm.slotFor(d)  // 1, 2, or nil
        let accent: Color = slot == 1 ? Theme.Palette.racingRed
            : slot == 2 ? Theme.Palette.info : Color.team(d.teamColor)
        let selected = slot != nil
        return Button {
            vm.select(d, year: year)
        } label: {
            VStack(spacing: 2) {
                Text(d.code ?? "?")
                    .font(.subheadline.weight(.bold))
                Text(d.teamName ?? "")
                    .font(.caption2).lineLimit(1).minimumScaleFactor(0.9)
            }
            .foregroundStyle(selected ? .black : Theme.Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
            .padding(.horizontal, 4)
            .background(selected ? accent : Theme.Palette.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Color.team(d.teamColor), lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(d.fullName)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Results
    @ViewBuilder private var results: some View {
        switch vm.compareState {
        case .idle:
            EmptyStateView(icon: "person.2.badge.gearshape", title: "Pick Two Drivers",
                           message: "Select two drivers above to compare their season head-to-head.")
                .frame(height: 220)
        case .loading:
            LoadingIndicator(label: "Comparing").frame(height: 220)
        case .failed(let msg):
            ErrorState(message: msg) { Task { await vm.compare(year: year) } }.frame(height: 220)
        case .loaded(let resp):
            if resp.drivers.count == 2 {
                comparison(resp.drivers[0], resp.drivers[1])
            }
        }
    }

    private func comparison(_ a: CompareDriver, _ b: CompareDriver) -> some View {
        VStack(spacing: Theme.Space.sm) {
            Card {
                VStack(spacing: Theme.Space.sm) {
                    Text("HEAD-TO-HEAD RECORD")
                        .font(.caption.weight(.bold)).tracking(1)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    h2hBar(label: "Race", aVal: a.raceWinsH2h, bVal: b.raceWinsH2h)
                    h2hBar(label: "Qualifying", aVal: a.qualWinsH2h, bVal: b.qualWinsH2h)
                }
            }
            statRow("Points", a.pointsLabel, b.pointsLabel, a.points, b.points)
            statRow("Wins", "\(a.wins)", "\(b.wins)", Double(a.wins), Double(b.wins))
            statRow("Podiums", "\(a.podiums)", "\(b.podiums)", Double(a.podiums), Double(b.podiums))
            statRow("Poles", "\(a.poles)", "\(b.poles)", Double(a.poles), Double(b.poles))
            statRow("Best Finish", best(a.bestFinish), best(b.bestFinish),
                    a.bestFinish.map { -Double($0) } ?? -99, b.bestFinish.map { -Double($0) } ?? -99)
            statRow("DNFs", "\(a.dnf)", "\(b.dnf)", -Double(a.dnf), -Double(b.dnf))
        }
    }

    private func h2hBar(label: String, aVal: Int, bVal: Int) -> some View {
        let total = max(aVal + bVal, 1)
        return VStack(spacing: 2) {
            HStack {
                Text("\(aVal)").font(.headline.weight(.bold)).foregroundStyle(Theme.Palette.racingRed)
                Spacer()
                Text(label).font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text("\(bVal)").font(.headline.weight(.bold)).foregroundStyle(Theme.Palette.info)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule().fill(Theme.Palette.racingRed)
                        .frame(width: geo.size.width * CGFloat(aVal) / CGFloat(total))
                    Capsule().fill(Theme.Palette.info)
                        .frame(width: geo.size.width * CGFloat(bVal) / CGFloat(total))
                }
            }
            .frame(height: 6)
        }
    }

    private func statRow(_ label: String, _ aText: String, _ bText: String,
                         _ aScore: Double, _ bScore: Double) -> some View {
        HStack {
            Text(aText)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(aScore >= bScore ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if aScore > bScore { winnerDot(Theme.Palette.racingRed) }
            Text(label.uppercased())
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 90)
            if bScore > aScore { winnerDot(Theme.Palette.info) }
            Text(bText)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(bScore >= aScore ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func winnerDot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 6, height: 6)
    }

    private func best(_ pos: Int?) -> String { pos.map { "P\($0)" } ?? "—" }
}

@MainActor
final class HeadToHeadViewModel: ObservableObject {
    @Published var drivers: [Driver] = []
    @Published var loadingDrivers = false
    @Published var driver1: Driver?
    @Published var driver2: Driver?
    @Published var compareState: Loadable<CompareResponse> = .idle

    func loadDrivers(year: Int) async {
        guard drivers.isEmpty else { return }
        loadingDrivers = true
        defer { loadingDrivers = false }
        do {
            drivers = try await APIClient.shared.drivers(year: year)
        } catch {
            drivers = []
        }
    }

    /// Which slot a driver occupies: 1, 2, or nil.
    func slotFor(_ d: Driver) -> Int? {
        if driver1?.id == d.id { return 1 }
        if driver2?.id == d.id { return 2 }
        return nil
    }

    /// Tap logic: fill slot 1 then slot 2; tapping a selected driver removes it;
    /// tapping a third driver replaces slot 2.
    func select(_ d: Driver, year: Int) {
        Haptics.selection()
        if driver1?.id == d.id {
            driver1 = nil
        } else if driver2?.id == d.id {
            driver2 = nil
        } else if driver1 == nil {
            driver1 = d
        } else if driver2 == nil {
            driver2 = d
        } else {
            driver2 = d
        }
        Task { await compare(year: year) }
    }

    func compare(year: Int) async {
        guard let d1 = driver1, let d2 = driver2, d1.driverId != d2.driverId else {
            compareState = .idle
            return
        }
        compareState = .loading
        do {
            compareState = .loaded(try await APIClient.shared.compare(year: year, d1: d1.driverId, d2: d2.driverId))
        } catch {
            compareState = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
