import SwiftUI

struct TitleScenarioMatrixView: View {
    let year: Int
    @State private var data: TitleScenariosResponse?

    var body: some View {
        Group {
            if let data, data.available, data.drivers.count >= 2 {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("TITLE PERMUTATIONS")
                        .font(.caption.weight(.bold)).tracking(1)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("Rows: \(data.drivers[0].code). Columns: \(data.drivers[1].code).")
                        .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                    if let text = data.clinchText {
                        Text(text).font(.subheadline.weight(.semibold))
                            .padding(Theme.Space.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Palette.positive.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 3) {
                                Color.clear.frame(width: 42, height: 24)
                                ForEach(data.positions, id: \.self) { Text(label($0)).font(.caption2).frame(width: 34) }
                            }
                            ForEach(data.positions, id: \.self) { row in
                                HStack(spacing: 3) {
                                    Text(label(row)).font(.caption2).frame(width: 42)
                                    ForEach(data.positions, id: \.self) { column in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(color(cell(data, row, column)?.outcome))
                                            .frame(width: 34, height: 34)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Space.md)
                .background(Theme.Palette.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
        .task(id: year) {
            data = try? await APIClient.shared.titleScenarios(year: year)
        }
    }

    private func cell(_ data: TitleScenariosResponse, _ row: Int, _ column: Int) -> TitleScenarioCell? {
        data.cells.first { $0.d1Position == row && $0.d2Position == column }
    }
    private func label(_ position: Int) -> String { position == 0 ? "DNF" : "P\(position)" }
    private func color(_ outcome: String?) -> Color {
        switch outcome {
        case "D1_CLINCHED": Theme.Palette.positive
        case "D2_CLINCHED": Theme.Palette.negative
        case "D1_LEADS": Theme.Palette.positive.opacity(0.35)
        case "D2_LEADS": Theme.Palette.negative.opacity(0.35)
        default: Theme.Palette.textTertiary.opacity(0.7)
        }
    }
}
