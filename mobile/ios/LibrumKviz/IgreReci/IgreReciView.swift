import SwiftUI

/// Igre reči: šest dnevnih zagonetki, ista za sve igrače.
struct IgreReciView: View {
    @Environment(Sesija.self) private var sesija
    private var stanje: IgreReci { IgreReci.deljeno }

    var body: some View {
        ZStack {
            Papir()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GornjaTraka()
                    Naslov(tekst: "Igre reči")
                    Text("Šest novih zagonetki svaki dan. Ista zagonetka za sve, rang lista do ponoći.")
                        .font(.tekst(15)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                    switch stanje.dan {
                    case .ucitava:
                        UcitavanjeMaskota(maskota: .lumi, tekst: "Slažem zagonetke…").frame(maxWidth: .infinity).padding(.top, 40)
                    case .greska(let g):
                        StanjeEkrana(maskota: .bloop, naslov: "Zagonetke nisu stigle", tekst: g, dugme: "Pokušaj ponovo") {
                            Task { await stanje.ucitaj(sesija) }
                        }
                    case .gotovo(let d):
                        if let t = d.igre.petSlova?.tezina {
                            // nedelja ide od lakog ka teškom (alati/igre_reci.py tezina_dana)
                            Text(t == "lako" ? "Danas: lake zagonetke" : t == "tesko" ? "Danas: teške zagonetke (vikend)" : "Danas: srednje zagonetke")
                                .font(.tekst(14, .bold)).foregroundStyle(t == "tesko" ? Color.crvena : t == "lako" ? Color.teal : Color.narandzasta)
                        }
                        NavigationLink { TakmicenjeView(pocetnaIgra: .petSlova) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.3.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.tinta)
                                    .frame(width: 44, height: 44).background(Color.zuta, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mastilo, lineWidth: 2))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Igraj sa drugima").font(.tekst(16, .bold))
                                    Text("2–8 igrača, ista zagonetka, lako do teško").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sivaTekst)
                            }
                            .foregroundStyle(Color.mastilo).padding(12).pop(radijus: 18)
                        }
                        .buttonStyle(.plain)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(IgraReci.allCases) { igra in
                                NavigationLink { odrediste(igra, d) } label: { kartica(igra) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await stanje.ucitaj(sesija) }
    }

    @ViewBuilder private func odrediste(_ igra: IgraReci, _ d: DanReci) -> some View {
        let z = d.igre
        Group {
            switch igra {
            case .premetaljka: if let p = z.premetaljka { PremetaljkaView(z: p, datum: d.datum) }
            case .petSlova: if let p = z.petSlova { PetSlovaView(z: p, datum: d.datum) }
            case .lanac: if let p = z.lanac { LanacView(z: p, datum: d.datum) }
            case .sifra: if let p = z.sifra { SifraView(z: p, datum: d.datum) }
            case .ukrstenica: if let p = z.ukrstenica { UkrstenicaView(z: p, datum: d.datum) }
            case .zmija: if let p = z.zmija { ZmijaView(z: p, datum: d.datum) }
            }
        }
        .bezSvajpaNazad()
    }

    private func kartica(_ igra: IgraReci) -> some View {
        let moj = stanje.moj(igra)
        let niz = stanje.niz(igra)
        return VStack(alignment: .leading, spacing: 10) {
            Image(systemName: igra.ikonica).font(.system(size: 22, weight: .bold))
                .foregroundStyle(igra.boja == .zuta || igra.boja == .narandzasta || igra.boja == .nebo ? Color.tinta : Color.white)
                .frame(width: 48, height: 48)
                .background(igra.boja, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
            VStack(alignment: .leading, spacing: 3) {
                Text(igra.naslov).font(.tekst(16, .bold)).foregroundStyle(Color.mastilo).lineLimit(1).minimumScaleFactor(0.8)
                Text(igra.opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if let moj {
                    Image(systemName: moj.resio ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(moj.resio ? Color.teal : Color.crvena)
                    Text(AzbukaReci.vreme(moj.sekundi)).monospacedDigit()
                } else {
                    Image(systemName: "play.fill")
                    Text("Igraj")
                }
                Spacer()
                if niz > 0 {
                    Image(systemName: "calendar")
                    Text("\(niz)").monospacedDigit()
                }
            }
            .font(.tekst(13, .bold)).foregroundStyle(Color.mastilo)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .pop(radijus: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(igra.naslov). \(igra.opis). " + (moj.map { $0.resio ? "Rešeno danas." : "Odigrano danas." } ?? "Nije odigrano.") + (niz > 0 ? " Niz \(niz) dana." : ""))
    }
}

/// Kartica na početnoj: ulaz u šest igara reči.
struct IgreReciKartica: View {
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: -10) {
                ForEach([IgraReci.premetaljka, .petSlova, .zmija], id: \.self) { igra in
                    Image(systemName: igra.ikonica).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.tinta)
                        .frame(width: 36, height: 36)
                        .background(igra.boja, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Igre reči").font(.tekst(16, .bold))
                Text("6 novih zagonetki svaki dan").font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sivaTekst)
        }
        .foregroundStyle(Color.mastilo).padding(12).pop(radijus: 20)
        .accessibilityElement(children: .combine)
    }
}
