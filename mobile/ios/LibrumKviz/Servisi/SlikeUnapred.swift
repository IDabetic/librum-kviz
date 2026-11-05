import UIKit

/// Slike pitanja (Slikari) preuzete unapred, čim se učita kviz, da se na pitanju pojave odmah.
/// Wikimedia ne šalje Cache-Control, pa se na URLCache ne oslanjamo: slike drži NSCache u memoriji.
@MainActor
final class SlikeUnapred {
    static let deljene = SlikeUnapred()
    private let kes = NSCache<NSURL, UIImage>()
    private var uToku: [URL: Task<UIImage?, Never>] = [:]

    private init() { kes.countLimit = 60 }

    /// Već preuzeta slika, ili nil.
    ///
    ///     if let s = SlikeUnapred.deljene.gotova(url) { Image(uiImage: s) }
    func gotova(_ url: URL) -> UIImage? { kes.object(forKey: url as NSURL) }

    /// Pokreće preuzimanje svih slika kviza; ponovni poziv za isti URL ne preuzima dva puta.
    ///
    ///     SlikeUnapred.deljene.pripremi(pitanja.compactMap { $0.slika.flatMap(URL.init) })
    func pripremi(_ urlovi: [URL]) {
        for url in urlovi { _ = ucitaj(url) }
    }

    /// Slika iz keša, iz preuzimanja koje je u toku, ili novo preuzimanje; nil kad slika ne stigne.
    func slika(_ url: URL) async -> UIImage? { await ucitaj(url).value }

    private func ucitaj(_ url: URL) -> Task<UIImage?, Never> {
        if let s = gotova(url) { return Task { s } }
        if let t = uToku[url] { return t }
        let t = Task<UIImage?, Never> {
            defer { uToku[url] = nil }
            guard let (d, odgovor) = try? await URLSession.shared.data(from: url),
                  (odgovor as? HTTPURLResponse)?.statusCode == 200,
                  let slika = await UIImage(data: d)?.byPreparingForDisplay() else { return nil }
            kes.setObject(slika, forKey: url as NSURL)
            return slika
        }
        uToku[url] = t
        return t
    }
}
