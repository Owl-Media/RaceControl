import SwiftUI

struct TeamDetailView: View {
    let year: Int
    let team: Team
    @EnvironmentObject private var favorites: FavoritesStore
    private var accent: Color { .team(team.teamColor) }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.md) {
                header
                Card {
                    HStack {
                        StatCell(value: team.positionInt.map(String.init) ?? "–", label: "Position")
                        Divider().frame(height: 36).overlay(Theme.Palette.stroke)
                        StatCell(value: team.pointsString, label: "Points", accent: accent)
                        Divider().frame(height: 36).overlay(Theme.Palette.stroke)
                        StatCell(value: team.wins?.numberLabel ?? "0", label: "Wins")
                    }
                }
                driversSection
            }
            .padding(Theme.Space.md)
        }
        .background(Theme.Palette.background)
        .navigationTitle(team.teamName ?? "Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteStar(isOn: favorites.isFavoriteTeam(team.teamId),
                             action: { if let id = team.teamId { favorites.toggleTeam(id) } }, size: 18)
            }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 54))
                .foregroundStyle(accent)
            Text(team.teamName ?? "")
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("\(CountryFlag.flag(country: team.nationality)) \(team.nationality ?? "")")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
        .background(
            LinearGradient(colors: [accent.opacity(0.30), Theme.Palette.surface],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: Theme.Radius.lg)
        )
    }

    @ViewBuilder private var driversSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("DRIVERS")
                .font(.caption.weight(.bold)).tracking(1)
                .foregroundStyle(Theme.Palette.textSecondary)
            ForEach(team.drivers) { d in
                HStack(spacing: Theme.Space.md) {
                    DriverAvatar(url: d.headshotUrl, initials: d.code ?? "?", accent: accent, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.name ?? "")
                            .font(.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        if let num = d.number?.stringValue {
                            Text("#\(num)")
                                .font(.subheadline)
                                .foregroundStyle(accent)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .padding(Theme.Space.md)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }
}
