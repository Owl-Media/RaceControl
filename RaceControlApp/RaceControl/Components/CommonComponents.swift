import SwiftUI

// MARK: - Season picker (menu in the nav bar)

struct SeasonPicker: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Menu {
            ForEach(appState.seasons, id: \.self) { year in
                Button {
                    appState.selectedYear = year
                } label: {
                    if year == appState.selectedYear {
                        Label(String(year), systemImage: "checkmark")
                    } else {
                        Text(String(year))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(String(appState.selectedYear))
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, Theme.Space.sm)
            .frame(minHeight: 32)
            .background(Theme.Palette.surfaceElevated, in: Capsule())
        }
    }
}

// MARK: - Driver avatar (async headshot with graceful fallback)

struct DriverAvatar: View {
    let url: String?
    let initials: String
    let accent: Color
    var size: CGFloat = 48

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    accent.opacity(0.22)
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(accent.opacity(0.5), lineWidth: 1.5))
    }
}

// MARK: - Team logo

/// Team logo with a graceful fallback when the hardcoded F1.com CDN URL
/// (see backend `_team_logo_url`) is missing or fails to load: no logo
/// field exists in FastF1/Ergast, so this is a manually maintained mapping
/// that renders nothing rather than a broken-image glyph if it's stale.
/// The source marks are white PNGs, so they sit on a dark chip to stay
/// legible against any background.
struct TeamLogoView: View {
    let url: String?
    var size: CGFloat = 24

    var body: some View {
        if let url, let parsed = URL(string: url) {
            AsyncImage(url: parsed) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                        .padding(size * 0.12)
                        .frame(width: size, height: size)
                        .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Team colour accent bar

struct TeamAccentBar: View {
    let color: Color
    var width: CGFloat = 4
    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(color)
            .frame(width: width)
    }
}

// MARK: - Position badge

struct PositionBadge: View {
    let text: String
    var highlight: Bool = false
    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(highlight ? Color.black : Theme.Palette.textPrimary)
            .frame(width: 34, height: 34)
            .background(
                highlight ? AnyShapeStyle(podiumGradient) : AnyShapeStyle(Theme.Palette.surfaceElevated),
                in: RoundedRectangle(cornerRadius: Theme.Radius.sm)
            )
    }

    private var podiumGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "FFD700"), Color(hex: "FFB300")],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Points pill

struct PointsPill: View {
    let points: String
    var body: some View {
        Text(points.isEmpty ? "0" : points)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, Theme.Space.sm)
            .frame(height: 26)
            .background(Theme.Palette.surfaceElevated, in: Capsule())
    }
}

// MARK: - Grid delta indicator (places gained / lost)

struct GridDeltaTag: View {
    let delta: Int
    var body: some View {
        Group {
            if delta == 0 {
                Label("0", systemImage: "equal")
                    .foregroundStyle(Theme.Palette.textTertiary)
            } else if delta > 0 {
                Label("\(delta)", systemImage: "arrow.up")
                    .foregroundStyle(Theme.Palette.positive)
            } else {
                Label("\(abs(delta))", systemImage: "arrow.down")
                    .foregroundStyle(Theme.Palette.negative)
            }
        }
        .font(.caption2.weight(.bold))
        .labelStyle(.titleAndIcon)
    }
}

// MARK: - Tyre badge

struct TyreBadge: View {
    let compound: String?
    var size: CGFloat = 26
    var body: some View {
        Text(TyreCompound.letter(compound))
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.black)
            .frame(width: size, height: size)
            .background(Circle().fill(TyreCompound.color(compound)))
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Section card container

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(Theme.Space.md)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Palette.stroke, lineWidth: 1)
            )
    }
}

// MARK: - Stat cell

struct StatCell: View {
    let value: String
    let label: String
    var accent: Color = Theme.Palette.textPrimary
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(accent)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}
