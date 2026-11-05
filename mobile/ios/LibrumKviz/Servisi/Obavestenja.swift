import UIKit
import UserNotifications
import MetricKit

/// Obaveštenja (izazov na duel, novi pratilac): APNs token ide u tabelu push_tokeni,
/// a server (Supabase funkcija obavesti) šalje preko Firebase/APNs. Bez naloga se ne prijavljuje.
final class AplikacijaDelegat: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Pad 03.11 nije mogao da se ponovi: Apple predaje izveštaj o padu pri sledećem pokretanju, a on ide u bazu.
        MXMetricManager.shared.add(self)
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in await Obavestenja.sacuvajToken(token) }
    }

    /// Obaveštenje stiže dok je aplikacija otvorena: prikaži ga kao baner, tiho.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}

@MainActor
enum Obavestenja {
    /// Posle prijave: traži dozvolu (ako je igrač već nije odbio) i registruje uređaj.
    static func prijavi() async {
        let centar = UNUserNotificationCenter.current()
        let stanje = await centar.notificationSettings().authorizationStatus
        if stanje == .notDetermined { _ = try? await centar.requestAuthorization(options: [.alert, .badge, .sound]) }
        guard await centar.notificationSettings().authorizationStatus == .authorized else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    static func sacuvajToken(_ token: String) async {
        guard let s = Sesija.trenutna, let id = s.korisnikId, let t = try? await s.vazeciToken() else { return }
        _ = try? await Supabase.deljeni.zahtev("rest/v1/push_tokeni", metod: "POST",
            telo: ["user_id": id, "token": token, "platforma": "ios", "updated_at": ISO8601DateFormatter().string(from: Date())],
            token: t, upit: [.init(name: "on_conflict", value: "user_id,token")], dodatnaZaglavlja: ["Prefer": "resolution=merge-duplicates"])
    }
}

extension AplikacijaDelegat: MXMetricManagerSubscriber {
    /// Stek poziva pada (bez ličnih podataka) ide u `izvestaji_o_padu`; čita se samo iz SQL konzole.
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let verzija = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
            + " (" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?") + ")"
        let izvestaji = payloads.flatMap { ($0.crashDiagnostics ?? []) + ($0.hangDiagnostics ?? []) }
            .compactMap { try? JSONSerialization.jsonObject(with: $0.jsonRepresentation()) }
        for izvestaj in izvestaji {
            Task {
                do {
                    _ = try await Supabase.deljeni.zahtev("rest/v1/izvestaji_o_padu", metod: "POST",
                                                          telo: ["platforma": "ios", "verzija": verzija, "izvestaj": izvestaj])
                } catch {
                    print("Izveštaj o padu nije poslat: \(error)")
                }
            }
        }
    }
}
