import XCTest
import SwiftUI
@testable import LibrumKviz

@MainActor
final class DeljenjeTests: XCTestCase {
    /// Slika za story ima tačne dimenzije (1080×1920) i nije prazna.
    func testStorySlika() throws {
        let r = ImageRenderer(content: KarticaRezultata(format: .story, igra: "Slikari", naslov: "Savršeno!", veliko: "10/10",
                                                        detalji: ["1.240 poena", "100% tačno"], ilustracija: "Igra_slikari", ime: "Ivan", avatar: "s3:2:4", boja: Color(hex: 0xFF5FA2)))
        r.scale = 1
        let slika = try XCTUnwrap(r.uiImage)
        XCTAssertEqual(slika.size, CGSize(width: 1080, height: 1920))
        try slika.pngData()?.write(to: URL(fileURLWithPath: "/tmp/claude-501/story.png"))
    }
}
