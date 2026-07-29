import SwiftUI

/// Session weather conditions: temperatures, humidity, wind and rainfall.
struct WeatherView: View {
    let year: Int
    let round: Int
    let title: String

    @StateObject private var vm = WeatherViewModel()

    var body: some View {
        LoadableView(state: vm.state) {
            await vm.load(year: year, round: round)
        } content: { wx in
            if !wx.available {
                EmptyStateView(icon: "cloud.slash", title: "No Weather Data",
                               message: "Weather data isn't available for this session.")
            } else {
                content(wx)
            }
        }
        .navigationTitle("Weather")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Palette.background)
        .task { await vm.load(year: year, round: round) }
    }

    private func content(_ wx: WeatherResponse) -> some View {
        ScrollView {
            VStack(spacing: Theme.Space.md) {
                if wx.rainfall == true {
                    banner(icon: "cloud.rain.fill", text: "Wet session: rainfall recorded",
                           color: Theme.Palette.info)
                } else {
                    banner(icon: "sun.max.fill", text: "Dry session", color: Theme.Palette.warning)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: Theme.Space.md) {
                    metric("Air Temp", value: wx.airTemp, unit: "°C", icon: "thermometer.medium",
                           detail: wx.airTempMax.map { "max \(fmt($0))°" })
                    metric("Track Temp", value: wx.trackTemp, unit: "°C", icon: "road.lanes",
                           detail: wx.trackTempMax.map { "max \(fmt($0))°" })
                    metric("Humidity", value: wx.humidity, unit: "%", icon: "humidity.fill")
                    metric("Wind", value: wx.windSpeed, unit: " m/s", icon: "wind")
                    metric("Pressure", value: wx.pressure, unit: " mbar", icon: "gauge.medium")
                }
            }
            .padding(Theme.Space.md)
        }
    }

    private func banner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(text).font(.headline).foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func metric(_ label: String, value: Double?, unit: String, icon: String,
                        detail: String? = nil) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.Palette.racingRed)
                Text(value.map { "\(fmt($0))\(unit)" } ?? "–")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(label).font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                if let detail {
                    Text(detail).font(.caption2).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }
}

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var state: Loadable<WeatherResponse> = .idle

    func load(year: Int, round: Int) async {
        if case .loaded = state { return }
        state = .loading
        do {
            state = .loaded(try await APIClient.shared.weather(year: year, round: round, session: "R"))
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
