import SwiftUI
import UIKit

/// Svajp sleva nadesno = nazad, i kad je sistemsko dugme „nazad” sakriveno (aplikacija ima svoje).
/// SwiftUI sa `navigationBarBackButtonHidden` gasi taj gest; ovde se vraća za ceo NavigationStack.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && SvajpNazad.zakljucano == 0
    }
}

/// Brojač ekrana koji ne smeju da se napuste svajpom (pitanje sa satom: izlaz bi prekinuo partiju bez pitanja).
@MainActor
enum SvajpNazad {
    static var zakljucano = 0
}

extension View {
    /// Isključuje svajp nazad dok je `aktivno` tačno, npr. dok teče pitanje.
    ///
    ///     KvizPitanjaView(...).bezSvajpaNazad()
    func bezSvajpaNazad(_ aktivno: Bool = true) -> some View {
        modifier(BezSvajpaNazad(aktivno: aktivno))
    }
}

private struct BezSvajpaNazad: ViewModifier {
    let aktivno: Bool
    @State private var drzi = false

    func body(content: Content) -> some View {
        content
            .onAppear { postavi(aktivno) }
            .onDisappear { postavi(false) }
            .onChange(of: aktivno) { _, novo in postavi(novo) }
    }

    private func postavi(_ novo: Bool) {
        guard novo != drzi else { return }
        drzi = novo
        SvajpNazad.zakljucano += novo ? 1 : -1
    }
}
