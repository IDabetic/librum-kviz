import SwiftUI

/// Sve kategorije kvizova (Explore iz kita, bez pretrage: vlasnik je odlučio da pretraga ne treba).
struct IstraziView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka()
                Naslov(tekst: "Kategorije", velicina: 36)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(KvizKatalog.kategorije, id: \.naziv) { k in
                        NavigationLink { KategorijaView(naziv: k.naziv) } label: { kategorija(k.naziv, k.ikonica, k.boja) }
                    }
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func kategorija(_ naziv: String, _ ikonica: String, _ boja: UInt32) -> some View {
        let broj = KvizKatalog.sve.filter { $0.kategorija == naziv }.count
        let tekst: Color = boja == 0x6EC3F2 || boja == 0xF4A33C ? .tinta : .white
        return VStack(alignment: .leading, spacing: 4) {
            Image(systemName: ikonica).font(.system(size: 18, weight: .semibold)).foregroundStyle(tekst)
                .frame(width: 40, height: 40).overlay(Circle().stroke(tekst, lineWidth: 1.5))
            Spacer()
            Text(naziv).font(.naslov(20)).foregroundStyle(tekst)
            Text("\(broj) kvizova").font(.tekst(12, .semibold)).foregroundStyle(tekst.opacity(0.85))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).frame(height: 130)
        .pop(Color(hex: boja), radijus: 20)
    }
}

/// Kategorija iz kita: naslovna kartica sa „Brzo igraj”, sortiranje i spisak.
/// Stanje „sve odigrano” kad je svaki kviz iz kategorije bar jednom igran.
struct KategorijaView: View {
    @Environment(Napredak.self) private var napredak
    let naziv: String
    enum Red: Hashable { case popularno, neodigrano, najbolje }
    @State private var red: Red = .popularno
    @State private var brzo: KvizStavka?

    private var boja: UInt32 { KvizKatalog.kategorije.first { $0.naziv == naziv }?.boja ?? 0x12907E }
    private var sve: [KvizStavka] { KvizKatalog.sve.filter { $0.kategorija == naziv } }
    private var lista: [KvizStavka] {
        switch red {
        case .popularno: sve
        case .neodigrano: sve.filter { napredak.s.najbolje[$0.id] == nil }
        case .najbolje: sve.filter { napredak.s.najbolje[$0.id] != nil }.sorted { (napredak.s.najbolje[$0.id] ?? 0) > (napredak.s.najbolje[$1.id] ?? 0) }
        }
    }
    private var sveOdigrano: Bool { sve.allSatisfy { napredak.s.najbolje[$0.id] != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GornjaTraka()
            let tekst: Color = boja == 0x6EC3F2 || boja == 0xF4A33C ? .tinta : .white
            ZStack(alignment: .leading) {
                MaskotaSlika(maskota: .mimi, velicina: 120).frame(maxWidth: .infinity, alignment: .trailing).offset(y: 18)
                VStack(alignment: .leading, spacing: 6) {
                    Text(naziv).font(.naslov(32)).foregroundStyle(tekst)
                    Text("\(sve.count) kvizova · \(sve.filter { napredak.s.najbolje[$0.id] != nil }.count) odigrano").font(.tekst(13, .semibold)).foregroundStyle(tekst.opacity(0.85))
                    Button { brzo = sve.filter { napredak.nivo >= $0.nivo }.randomElement() } label: {
                        Text("Brzo igraj").font(.tekst(14, .bold)).foregroundStyle(.white).padding(.horizontal, 16).frame(height: 40)
                            .background(Color.tinta, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .padding(.top, 6)
                }
                .padding(18)
            }
            .frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .pop(Color(hex: boja), radijus: 26)
            PodvuceniIzbor(izbor: $red, opcije: [(.popularno, "Popularno"), (.neodigrano, "Neodigrano"), (.najbolje, "Moji najbolji")])
            ScrollView {
                VStack(spacing: 10) {
                    if sveOdigrano && red != .najbolje {
                        Label("Sve iz ove kategorije si odigrao. Popravi rekorde!", systemImage: "checkmark.seal").font(.tekst(14, .bold))
                            .foregroundStyle(Color.tinta).padding(12).frame(maxWidth: .infinity, alignment: .leading).pop(.zuta, radijus: 16)
                    }
                    if lista.isEmpty {
                        StanjeEkrana(maskota: .bloop, naslov: red == .neodigrano ? "Sve odigrano!" : "Još ništa",
                                     tekst: red == .neodigrano ? "Nema više neodigranih kvizova ovde." : "Odigraj kviz iz ove kategorije i rezultat će stajati ovde.")
                    }
                    ForEach(lista) { s in NavigationLink { KvizOdrediste(stavka: s) } label: { KvizRed(stavka: s) } }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $brzo) { KvizOdrediste(stavka: $0) }
    }
}
