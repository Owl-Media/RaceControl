import Foundation

/// Networking layer for the RaceControl FastF1 backend.
///
/// The App Store build always uses the production RaceControl backend. Self-hosted
/// builds can point elsewhere by changing `AppConfig.apiBaseURL` before building.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45        // FastF1 loads can be slow
        config.timeoutIntervalForResource = 90
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    var baseURL: URL {
        AppConfig.apiBaseURL
    }

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        // Build the URL by string so query strings (`?d1=…`) are preserved;
        // URL.append(path:) would percent-encode the `?`.
        var base = baseURL.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        let prefix = path.hasPrefix("/") ? "" : "/"
        guard let url = URL(string: base + prefix + path) else {
            throw APIError.invalidResponse
        }

        // First attempt, then one retry with a fresh App Attest token on 401
        // (covers a token that expired or a server key-store reset).
        do {
            return try await perform(url: url, as: type)
        } catch APIError.server(let status, _) where status == 401 && usingAppAttest {
            await AppAttestService.shared.invalidateToken()
            return try await perform(url: url, as: type)
        }
    }

    private func perform<T: Decodable>(url: URL, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let header = await authorizationHeader() {
            request.setValue(header, forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                let detail = (try? decoder.decode(APIErrorBody.self, from: data))?.detail
                throw APIError.server(status: http.statusCode, detail: detail)
            }
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decoding(error)
        } catch {
            throw APIError.transport(error)
        }
    }

    /// True when we're relying on App Attest (no manual token set).
    private var usingAppAttest: Bool { Keychain.apiToken.isEmpty }

    /// Auth precedence: manual admin token (dev/break-glass) → App Attest token
    /// → nothing (local dev server with auth disabled).
    private func authorizationHeader() async -> String? {
        let manual = Keychain.apiToken
        if !manual.isEmpty { return "Bearer \(manual)" }
        if let token = await AppAttestService.shared.bearerToken(baseURL: baseURL) {
            return "Bearer \(token)"
        }
        return nil
    }
}

// MARK: - Endpoints
extension APIClient {
    func seasons() async throws -> [Int] {
        try await get("api/seasons", as: [Int].self)
    }
    func schedule(year: Int) async throws -> [RaceEvent] {
        try await get("api/schedule/\(year)", as: [RaceEvent].self)
    }
    func results(year: Int, round: Int, session: String) async throws -> SessionResultsResponse {
        try await get("api/results/\(year)/\(round)/\(session)", as: SessionResultsResponse.self)
    }
    func driverStandings(year: Int) async throws -> [DriverStanding] {
        try await get("api/standings/drivers/\(year)", as: [DriverStanding].self)
    }
    func constructorStandings(year: Int) async throws -> [ConstructorStanding] {
        try await get("api/standings/constructors/\(year)", as: [ConstructorStanding].self)
    }
    func drivers(year: Int) async throws -> [Driver] {
        try await get("api/drivers/\(year)", as: [Driver].self)
    }
    func driverDetail(year: Int, driverId: String) async throws -> DriverDetail {
        try await get("api/drivers/\(year)/\(driverId)", as: DriverDetail.self)
    }
    func teams(year: Int) async throws -> [Team] {
        try await get("api/teams/\(year)", as: [Team].self)
    }
    func teamDetail(year: Int, teamId: String) async throws -> Team {
        try await get("api/teams/\(year)/\(teamId)", as: Team.self)
    }
    func circuits(year: Int) async throws -> [Circuit] {
        try await get("api/circuits/\(year)", as: [Circuit].self)
    }
    func circuitMap(year: Int, round: Int) async throws -> CircuitMap {
        try await get("api/circuit/\(year)/\(round)", as: CircuitMap.self)
    }
    func replay(year: Int, round: Int) async throws -> RaceReplay {
        try await get("api/replay/\(year)/\(round)", as: RaceReplay.self)
    }
    func lapTimes(year: Int, round: Int) async throws -> LapTimesResponse {
        try await get("api/laptimes/\(year)/\(round)", as: LapTimesResponse.self)
    }
    func strategy(year: Int, round: Int) async throws -> StrategyResponse {
        try await get("api/strategy/\(year)/\(round)", as: StrategyResponse.self)
    }
    func weather(year: Int, round: Int, session: String) async throws -> WeatherResponse {
        try await get("api/weather/\(year)/\(round)/\(session)", as: WeatherResponse.self)
    }
    func raceDrivers(year: Int, round: Int) async throws -> [RaceDriver] {
        try await get("api/racedrivers/\(year)/\(round)", as: [RaceDriver].self)
    }
    func telemetry(year: Int, round: Int, driver: String, lap: String = "fastest") async throws -> TelemetryResponse {
        try await get("api/telemetry/\(year)/\(round)/\(driver)?lap=\(lap)", as: TelemetryResponse.self)
    }
    func telemetryCompare(year: Int, round: Int, d1: String, d2: String) async throws -> TelemetryCompareResponse {
        try await get("api/telemetry-compare/\(year)/\(round)?d1=\(d1)&d2=\(d2)", as: TelemetryCompareResponse.self)
    }
    func retirements(year: Int, round: Int) async throws -> RetirementsResponse {
        try await get("api/retirements/\(year)/\(round)", as: RetirementsResponse.self)
    }
    func flags(year: Int, round: Int, session: String = "R") async throws -> FlagsResponse {
        try await get("api/flags/\(year)/\(round)?session=\(session)", as: FlagsResponse.self)
    }
    func raceControl(year: Int, round: Int, session: String = "R") async throws -> RaceControlResponse {
        try await get("api/racecontrol/\(year)/\(round)?session=\(session)", as: RaceControlResponse.self)
    }
    func penalties(year: Int, round: Int, session: String = "R") async throws -> PenaltiesResponse {
        try await get("api/penalties/\(year)/\(round)?session=\(session)", as: PenaltiesResponse.self)
    }
    func reliability(year: Int) async throws -> ReliabilityResponse {
        try await get("api/reliability/\(year)", as: ReliabilityResponse.self)
    }
    func compare(year: Int, d1: String, d2: String) async throws -> CompareResponse {
        try await get("api/compare/\(year)/\(d1)/\(d2)", as: CompareResponse.self)
    }
    func standingsEvolution(year: Int) async throws -> StandingsEvolution {
        try await get("api/standings-evolution/\(year)", as: StandingsEvolution.self)
    }
}

// MARK: - Errors & config
enum APIError: LocalizedError {
    case invalidResponse
    case server(status: Int, detail: String?)
    case decoding(DecodingError)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .server(let status, let detail):
            if status == 401 {
                return "The server couldn't authenticate this app. Please try again."
            }
            return detail ?? "Server error (\(status))."
        case .decoding:
            return "Couldn't read the data from the server."
        case .transport(let error):
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                return "Can't reach the RaceControl server. Please try again later."
            }
            return error.localizedDescription
        }
    }
}

private struct APIErrorBody: Decodable { let detail: String? }

enum AppConfig {
    /// Self-hosted builds can replace this value with their own HTTPS backend.
    static let apiBaseURL = URL(string: "https://racecontrol.owl-media.co.uk")!
}
