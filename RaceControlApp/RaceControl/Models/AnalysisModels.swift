import Foundation

// MARK: - Lap-time evolution

struct LapTimesResponse: Codable {
    let year: Int
    let round: Int
    let eventName: String?
    let totalLaps: Int
    let drivers: [LapTimeDriver]
}

struct LapTimeDriver: Codable, Identifiable, Hashable {
    let code: String
    let driverId: String?
    let teamName: String?
    let teamColor: String?
    let laps: [LapTimePoint]
    var id: String { code }
}

struct LapTimePoint: Codable, Hashable {
    let lap: Int
    let timeMs: Int
    let compound: String?
    var seconds: Double { Double(timeMs) / 1000 }
}

// MARK: - Tyre strategy

struct StrategyResponse: Codable {
    let year: Int
    let round: Int
    let eventName: String?
    let totalLaps: Int
    let drivers: [StrategyDriver]
}

struct StrategyDriver: Codable, Identifiable, Hashable {
    let code: String
    let driverId: String?
    let teamName: String?
    let teamColor: String?
    let pitStops: Int
    let stints: [Stint]
    var id: String { code }
}

struct Stint: Codable, Hashable, Identifiable {
    let stint: Int
    let compound: String?
    let startLap: Int
    let endLap: Int
    let laps: Int
    var id: Int { stint }
}

// MARK: - Weather

struct WeatherResponse: Codable {
    let year: Int
    let round: Int
    let session: String
    let eventName: String?
    let available: Bool
    let airTemp: Double?
    let trackTemp: Double?
    let humidity: Double?
    let pressure: Double?
    let windSpeed: Double?
    let rainfall: Bool?
    let airTempMax: Double?
    let trackTempMax: Double?
}

// MARK: - Telemetry

struct TelemetryResponse: Codable {
    let year: Int
    let round: Int
    let available: Bool
    let eventName: String?
    let trace: TelemetryTrace?
}

struct TelemetryCompareResponse: Codable {
    let year: Int
    let round: Int
    let eventName: String?
    let available: Bool
    let traces: [TelemetryTrace]
}

struct TelemetryTrace: Codable, Identifiable, Hashable {
    let code: String
    let driverName: String?
    let teamName: String?
    let teamColor: String?
    let lapNumber: Int?
    let lapTime: String?
    let lapTimeMs: Int?
    let compound: String?
    let distance: [Double]
    let time: [Double]?
    let speed: [Double]
    let throttle: [Double]
    let brake: [Int]
    let gear: [Int]
    let rpm: [Int]
    let drs: [Int]
    let x: [Double]
    let y: [Double]
    var id: String { code }

    /// Zip distance + a channel into chartable points, capped for performance.
    func series(_ channel: [Double]) -> [TelemetrySample] {
        zip(distance, channel).map { TelemetrySample(distance: $0.0, value: $0.1) }
    }
}

struct TelemetrySample: Identifiable, Hashable {
    let distance: Double
    let value: Double
    var id: Double { distance }
}

// MARK: - Race drivers (picker)

struct RaceDriver: Codable, Identifiable, Hashable {
    let code: String?
    let driverId: String?
    let fullName: String?
    let teamName: String?
    let teamColor: String?
    let number: String?
    var id: String { code ?? driverId ?? UUID().uuidString }
}

// MARK: - Retirements

struct RetirementsResponse: Codable {
    let year: Int
    let round: Int
    let eventName: String?
    let retirements: [Retirement]
}

struct Retirement: Codable, Identifiable, Hashable {
    let driver: String?
    let fullName: String?
    let driverId: String?
    let teamName: String?
    let teamColor: String?
    let status: String?
    let classifiedPosition: String?
    var id: String { driver ?? driverId ?? UUID().uuidString }
}

// MARK: - Flags / Safety Car

struct FlagsResponse: Codable {
    let year: Int
    let round: Int
    let session: String
    let eventName: String?
    let totalLaps: Int
    let events: [FlagEvent]
    let periods: [FlagPeriod]
}

/// A single race-control message from the raw timeline.
struct FlagEvent: Codable, Identifiable, Hashable {
    let time: String?
    let lap: Int?
    let category: String?
    let flag: String?
    let status: String?
    let scope: String?
    let sector: Int?
    let driverNumber: String?
    let driverCode: String?
    let message: String?

    var id: String { "\(time ?? "-")|\(lap ?? -1)|\(category ?? "")|\(flag ?? "")|\(message ?? "")" }
}

/// A collapsed lap range during which a flag/safety-car condition was active —
/// used to band the lap-based charts (`YELLOW`, `DOUBLE_YELLOW`, `RED`, `SC`, `VSC`).
struct FlagPeriod: Codable, Identifiable, Hashable {
    let type: String
    let startLap: Int
    let endLap: Int
    let reason: String?

    var id: String { "\(type)-\(startLap)-\(endLap)" }

    /// True when `lap` falls within this period's inclusive lap range.
    func contains(lap: Int) -> Bool { lap >= startLap && lap <= endLap }
}

// MARK: - Race Control (full, unfiltered message log)

struct RaceControlResponse: Codable {
    let year: Int
    let round: Int
    let session: String
    let eventName: String?
    let totalLaps: Int
    let messages: [RaceControlMessage]
}

/// A single race-control message from the complete, unfiltered timeline —
/// flags, safety-car, DRS, car events and "other" (investigations, penalties).
struct RaceControlMessage: Codable, Identifiable, Hashable {
    let time: String?
    let lap: Int?
    let category: String?
    let flag: String?
    let status: String?
    let scope: String?
    let sector: Int?
    let driverNumber: String?
    let driverCode: String?
    let message: String?

    var id: String { "\(time ?? "-")|\(lap ?? -1)|\(category ?? "")|\(flag ?? "")|\(message ?? "")" }
}

// MARK: - Reliability

struct ReliabilityResponse: Codable {
    let year: Int
    let races: Int
    let drivers: [ReliabilityDriver]
    let teams: [ReliabilityTeam]
}

struct ReliabilityDriver: Codable, Identifiable, Hashable {
    let driverId: String
    let name: String
    let teamId: String?
    let finished: Int
    let mechanical: Int
    let accident: Int
    let disqualified: Int
    let other: Int
    let dnf: Int
    let starts: Int
    let finishRate: Double
    var id: String { driverId }
}

struct ReliabilityTeam: Codable, Identifiable, Hashable {
    let teamId: String
    let teamName: String?
    let finished: Int
    let mechanical: Int
    let accident: Int
    let disqualified: Int
    let other: Int
    let dnf: Int
    let starts: Int
    let finishRate: Double
    var id: String { teamId }
}

// MARK: - Standings evolution

struct StandingsEvolution: Codable {
    let year: Int
    let rounds: [Int]
    let drivers: [EvolutionDriver]
}

struct EvolutionDriver: Codable, Identifiable, Hashable {
    let driverId: String
    let name: String
    let code: String?
    let teamName: String?
    let teamColor: String?
    let points: Double
    let series: [EvolutionPoint]
    var id: String { driverId }
}

struct EvolutionPoint: Codable, Hashable {
    let round: Int
    let points: Double
}

// MARK: - Head-to-head compare

struct CompareResponse: Codable {
    let year: Int
    let drivers: [CompareDriver]
}

struct CompareDriver: Codable, Identifiable, Hashable {
    let driverId: String
    let name: String
    let teamName: String?
    let points: Double
    let wins: Int
    let podiums: Int
    let poles: Int
    let bestFinish: Int?
    let dnf: Int
    let raceWinsH2h: Int
    let qualWinsH2h: Int

    enum CodingKeys: String, CodingKey {
        case driverId, name, teamName, points, wins, podiums, poles, bestFinish, dnf
        case raceWinsH2h = "raceWins_h2h"
        case qualWinsH2h = "qualWins_h2h"
    }
    var id: String { driverId }
    var pointsLabel: String {
        points.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(points)) : String(points)
    }
}
