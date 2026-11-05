import Network
import Observation

/// Prati da li telefon ima internet, za stanja „Offline” iz kita.
@Observable
@MainActor
final class Mreza {
    static let deljena = Mreza()
    private(set) var povezan = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { putanja in
            let ima = putanja.status == .satisfied
            Task { @MainActor in Mreza.deljena.povezan = ima }
        }
        monitor.start(queue: DispatchQueue(label: "mreza"))
    }
}
