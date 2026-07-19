import SwiftUI
import DeviceCheck

/// Lets the user point the app at their RaceControl backend. Defaults to
/// localhost (works in the iOS Simulator); on a physical device set this to
/// the Mac's LAN address, e.g. http://192.168.1.20:8000.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("api_base_url") private var baseURL: String = AppConfig.defaultBaseURL
    @AppStorage("notifications_enabled") private var notificationsEnabled = false
    @AppStorage("notify_day_before") private var notifyDayBefore = true
    @AppStorage("notify_1hour") private var notify1Hour = false
    @AppStorage("notify_15min") private var notify15Min = true
    @AppStorage("notify_practice") private var notifyPractice = false
    @AppStorage("notify_qualifying") private var notifyQualifying = true
    @AppStorage("notify_sprint") private var notifySprint = true
    @AppStorage("notify_race") private var notifyRace = true
    @State private var draft: String = ""
    @State private var tokenDraft: String = ""
    @State private var status: ConnectionStatus = .unknown
    @State private var permissionDenied = false

    private var appAttestSupported: Bool { DCAppAttestService.shared.isSupported }

    enum ConnectionStatus: Equatable { case unknown, checking, ok, failed(String) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend Server") {
                    TextField("http://localhost:8000", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(.body, design: .monospaced))
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            statusIcon
                        }
                    }
                }

                Section {
                    LabeledContent("App Attest") {
                        Label(appAttestSupported ? "Active" : "Unavailable",
                              systemImage: appAttestSupported ? "checkmark.shield.fill" : "xmark.shield")
                            .foregroundStyle(appAttestSupported ? Theme.Palette.positive : Theme.Palette.textTertiary)
                            .labelStyle(.titleAndIcon)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text(appAttestSupported
                        ? "This device authenticates to the backend automatically using Apple App Attest — no key needed."
                        : "App Attest isn't available here (it doesn't run in the Simulator). Use the admin token below to reach a secured backend.")
                }

                Section {
                    SecureField("Admin token (optional)", text: $tokenDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Admin Token")
                } footer: {
                    Text("Optional break-glass credential matching the server's API_TOKEN. Overrides App Attest when set. Stored in the device Keychain.")
                }

                Section {
                    Button {
                        draft = AppConfig.defaultBaseURL
                    } label: {
                        Label("Reset to Default", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Run the FastF1 backend with `./run.sh`, then enter its address here. Use your Mac's local IP when testing on a physical iPhone, or your deployed HTTPS URL.")
                }

                Section {
                    Toggle("Race Reminders", isOn: $notificationsEnabled)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Reminders are scheduled on your device for the current season, timed to your local timezone.")
                }

                if notificationsEnabled {
                    Section("Remind me") {
                        Toggle("The day before", isOn: $notifyDayBefore)
                        Toggle("1 hour before", isOn: $notify1Hour)
                        Toggle("15 minutes before", isOn: $notify15Min)
                    }
                    Section("For these sessions") {
                        Toggle("Practice", isOn: $notifyPractice)
                        Toggle("Qualifying", isOn: $notifyQualifying)
                        Toggle("Sprint", isOn: $notifySprint)
                        Toggle("Race", isOn: $notifyRace)
                    }
                }

                Section("About") {
                    LabeledContent("Data", value: "FastF1 (2018–present)")
                    LabeledContent("App", value: "RaceControl 1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: notificationsEnabled) { _, on in
                Task {
                    if on {
                        let granted = await NotificationManager.shared.requestAuthorization()
                        if granted {
                            await NotificationManager.shared.refreshIfEnabled()
                        } else {
                            notificationsEnabled = false
                            permissionDenied = true
                        }
                    } else {
                        NotificationManager.shared.cancelAll()
                    }
                }
            }
            .onChange(of: notifyDayBefore) { _, _ in reschedule() }
            .onChange(of: notify1Hour) { _, _ in reschedule() }
            .onChange(of: notify15Min) { _, _ in reschedule() }
            .onChange(of: notifyPractice) { _, _ in reschedule() }
            .onChange(of: notifyQualifying) { _, _ in reschedule() }
            .onChange(of: notifySprint) { _, _ in reschedule() }
            .onChange(of: notifyRace) { _, _ in reschedule() }
            .alert("Notifications Disabled", isPresented: $permissionDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable notifications for RaceControl in the iOS Settings app to receive race reminders.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        baseURL = draft.trimmingCharacters(in: .whitespaces)
                        Keychain.apiToken = tokenDraft.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = baseURL
                tokenDraft = Keychain.apiToken
            }
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch status {
        case .unknown: EmptyView()
        case .checking: ProgressView()
        case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Palette.positive)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Palette.negative)
        }
    }

    private func reschedule() {
        Task { await NotificationManager.shared.refreshIfEnabled() }
    }

    /// Checks reachability via the open /api/health probe, then verifies the
    /// token against an authenticated endpoint so a bad token is caught here
    /// rather than showing up as errors all over the app.
    private func test() async {
        status = .checking
        let base = draft.trimmingCharacters(in: .whitespaces)
        let token = tokenDraft.trimmingCharacters(in: .whitespaces)
        guard let healthURL = URL(string: base)?.appending(path: "api/health"),
              let authURL = URL(string: base)?.appending(path: "api/seasons") else {
            status = .failed("Invalid URL"); return
        }
        do {
            let (_, healthResponse) = try await URLSession.shared.data(from: healthURL)
            guard let health = healthResponse as? HTTPURLResponse,
                  (200..<300).contains(health.statusCode) else {
                status = .failed("Server reachable but unhealthy"); return
            }

            var request = URLRequest(url: authURL)
            // Mirror the app's real auth precedence: admin token, else App Attest.
            var usedAttest = false
            if !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else if let baseURL = URL(string: base),
                      let attestToken = await AppAttestService.shared.bearerToken(baseURL: baseURL) {
                request.setValue("Bearer \(attestToken)", forHTTPHeaderField: "Authorization")
                usedAttest = true
            }
            let (_, authResponse) = try await URLSession.shared.data(for: request)
            guard let auth = authResponse as? HTTPURLResponse else {
                status = .failed("Bad response"); return
            }
            switch auth.statusCode {
            case 200..<300: status = .ok
            case 401: status = .failed({
                if !token.isEmpty { return "Admin token rejected" }
                if usedAttest { return "App Attest was rejected by the server" }
                return "This server requires authentication"
            }())
            default: status = .failed("Server error (\(auth.statusCode))")
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
