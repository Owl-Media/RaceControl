import SwiftUI

struct RaceDetailView: View {
    let event: RaceEvent
    @StateObject private var vm = RaceDetailViewModel()
    @State private var selectedSession: String = "R"

    /// Sessions that produce a classification worth showing.
    private var resultSessions: [(label: String, id: String)] {
        var out: [(String, String)] = []
        for s in event.sessions {
            guard let id = s.identifier, let name = s.name else { continue }
            switch id {
            case "R": out.append(("Race", "R"))
            case "Q": out.append(("Quali", "Q"))
            case "S": out.append(("Sprint", "S"))
            case "SQ", "SS": out.append(("Sprint Q", id))
            case "FP1", "FP2", "FP3": out.append((name.replacingOccurrences(of: "Practice", with: "FP"), id))
            default: break
            }
        }
        // Ensure Race first.
        return out.sorted { a, _ in a.1 == "R" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.md) {
                header
                if !event.sessions.isEmpty {
                    WeekendScheduleCard(event: event)
                }
                if event.completed {
                    RaceAnalysisGrid(event: event)
                }
                sessionPicker
                LoadableView(state: vm.state) {
                    await vm.load(year: event.year, round: event.round, session: selectedSession)
                } content: { response in
                    ResultsTable(response: response)
                }
                .frame(minHeight: 320)
            }
            .padding(Theme.Space.md)
        }
        .background(Theme.Palette.background)
        .navigationTitle(event.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedSession) {
            await vm.load(year: event.year, round: event.round, session: selectedSession)
        }
    }

    private var header: some View {
        Card {
            HStack(spacing: Theme.Space.md) {
                Text(CountryFlag.flag(country: event.country))
                    .font(.system(size: 52))
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.officialName ?? event.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text([event.location, event.country].compactMap { $0 }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    if let date = event.parsedDate {
                        Text(date.formatted(date: .long, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder private var sessionPicker: some View {
        if resultSessions.count > 1 {
            Picker("Session", selection: $selectedSession) {
                ForEach(resultSessions, id: \.id) { s in
                    Text(s.label).tag(s.id)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedSession) { _, _ in Haptics.selection() }
        }
    }
}

// MARK: - Results table

private struct ResultsTable: View {
    let response: SessionResultsResponse
    private var isQualifying: Bool { response.session == "Q" || response.session == "SQ" }

    var body: some View {
        if response.results.isEmpty {
            EmptyStateView(icon: "list.number", title: "No Results",
                           message: "Results aren't available for this session yet.")
                .frame(minHeight: 240)
        } else {
            VStack(spacing: Theme.Space.sm) {
                ForEach(response.results) { entry in
                    ResultRow(entry: entry, isQualifying: isQualifying,
                              winnerTimeMs: response.results.first?.timeMs)
                }
            }
        }
    }
}

private struct ResultRow: View {
    let entry: ResultEntry
    let isQualifying: Bool
    let winnerTimeMs: Int?

    private var accent: Color { .team(entry.teamColor) }
    private var isPodium: Bool { (entry.position ?? 99) <= 3 }

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            PositionBadge(text: entry.positionLabel, highlight: isPodium)
            TeamAccentBar(color: accent).frame(height: 40)

            DriverAvatar(url: entry.headshotUrl,
                         initials: entry.abbreviation ?? "?",
                         accent: accent, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fullName ?? entry.abbreviation ?? "Unknown")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(entry.teamName ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)

            trailing
        }
        .padding(.vertical, 6)
        .padding(.horizontal, Theme.Space.sm)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    @ViewBuilder private var trailing: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if isQualifying {
                Text(entry.q3 ?? entry.q2 ?? entry.q1 ?? "—")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else {
                Text(raceTime)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.Palette.textPrimary)
                HStack(spacing: 6) {
                    if let delta = entry.gridDelta { GridDeltaTag(delta: delta) }
                    if !entry.pointsLabel.isEmpty {
                        Text("+\(entry.pointsLabel)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.Palette.racingRedText)
                    }
                }
            }
        }
    }

    private var raceTime: String {
        if let status = entry.status, status != "Finished", !status.hasPrefix("+"),
           entry.timeMs == nil {
            return status // DNF, +1 Lap, Accident, etc.
        }
        guard let ms = entry.timeMs else { return entry.status ?? "—" }
        if entry.position == 1 {
            return format(ms: ms, leading: true)
        }
        if let winner = winnerTimeMs {
            let gap = ms - winner
            return "+" + format(ms: gap, leading: false)
        }
        return format(ms: ms, leading: true)
    }

    private func format(ms: Int, leading: Bool) -> String {
        let minutes = ms / 60_000
        let seconds = (ms % 60_000) / 1000
        let millis = ms % 1000
        if leading, minutes > 0 {
            return String(format: "%d:%02d.%03d", minutes, seconds, millis)
        }
        return String(format: "%d.%03d", seconds + minutes * 60, millis)
    }
}

@MainActor
final class RaceDetailViewModel: ObservableObject {
    @Published var state: Loadable<SessionResultsResponse> = .idle
    private var key: String?

    func load(year: Int, round: Int, session: String) async {
        let newKey = "\(year)-\(round)-\(session)"
        if key == newKey, case .loaded = state { return }
        state = .loading
        do {
            let response = try await APIClient.shared.results(year: year, round: round, session: session)
            state = .loaded(response)
            key = newKey
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
