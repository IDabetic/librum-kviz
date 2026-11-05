"""Kviz „Slikari” za aplikacije iz sređene baze (kviz-baze/prevod/slikari-sr.jsonl, alati/slikari_srpski.py tamo).

Ažurirano: 04.11.2026 · verzija 1 (zamenjuje alati/slikari-u-json.py)

- Samo pitanja sa slikom (vlasnik 03.11: Slikari bez slike nema); tekstualna su u konačnom fajlu baze.
- Slike su naši WebP fajlovi (800 px) na kviz.librum.club/slike/slikari/<Q>.webp, ne više link na Wikimediju;
  izvor (Wikimedia Commons) se i dalje navodi posle odgovora.
- Muzeji na srpskom iz alati/slikari-muzeji.tsv (engleski naziv iz Wikidate → srpski).
- `pitanje` je prazno osim kad naziv odaje autora („Rubens i Izabela Brant…” → „Ko je naslikao ovu sliku?”).

Upotreba (iz korena repoa):
  python3 -I alati/slikari-iz-baze.py ../Claude/kviz-baze
  → src/lib/igre/slikari.json + public/slike/slikari/*.webp
"""
import json
import os
import shutil
import sys

KORENI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(KORENI)
ADRESA_SLIKA = "https://kviz.librum.club/slike/slikari/"
PRAVCI = {"Ukiyo-e": "Ukijo-e", "De Stijl": "De Stajl"}


def muzeji():
    with open(os.path.join(KORENI, "slikari-muzeji.tsv"), encoding="utf-8") as f:
        # Red bez druge kolone znači „ne prikazuj” (privatni vlasnik, ugašena zbirka).
        return dict((l.rstrip("\n").split("\t", 1) + [""])[:2] for l in f if l.strip() and not l.startswith("#"))


# Autori umrli posle 1955: dela su još pod autorskim pravom (70 godina), pa ne idu u igru (vlasnik 04.11.2026, Apple 5.2.1).
ZASTICENI = {"Pablo Pikaso", "Salvador Dali", "Rene Magrit", "Mark Šagal", "Žoan Miro", "Endi Vorhol", "Roj Liktenstajn",
             "Edvard Hoper", "Džordžija O’Kif", "Dijego Rivera", "David Alfaro Sikejros", "Kandido Portinari",
             "Osvaldo Gvajasamin", "Tarsila do Amaral", "Sonja Delone", "Tamara de Lempicka"}


def main(baza):
    radni = {}
    for linija in open(os.path.join(baza, "prevod", "slikari", "radni.jsonl"), encoding="utf-8"):
        r = json.loads(linija)
        radni[r["id"]] = r
    mz = muzeji()
    folder = os.path.join(REPO, "public", "slike", "slikari")
    os.makedirs(folder, exist_ok=True)
    pitanja, vidjeno = [], set()
    for linija in open(os.path.join(baza, "prevod", "slikari-sr.jsonl"), encoding="utf-8"):
        p = json.loads(linija)
        if not p["slika"] or p["izvor_id"] in vidjeno or p["tacan"] in ZASTICENI:
            continue
        vidjeno.add(p["izvor_id"])
        r = radni[p["id"]]
        izvor = os.path.join(baza, p["slika"])
        cilj = os.path.join(folder, p["izvor_id"] + ".webp")
        if not os.path.exists(cilj) or os.path.getsize(cilj) != os.path.getsize(izvor):
            shutil.copyfile(izvor, cilj)
        pitanja.append({
            "id": "s-" + p["izvor_id"],
            "naziv": p["naziv"],
            "pitanje": p["pitanje"] if p["pitanje"] == "Ko je naslikao ovu sliku?" else "",
            "slika": ADRESA_SLIKA + p["izvor_id"] + ".webp",
            "izvor": p["izvor_slike"],
            "ponude": [p["tacan"], p["netacan_1"], p["netacan_2"], p["netacan_3"]],
            "godina": r["Godina"],
            "pravac": PRAVCI.get(r["Pravac"], r["Pravac"]),
            "zemlja": r["Zemlja"],
            "muzej": mz.get(r["Muzej"], r["Muzej"]),
            "tezina": p["tezina"] or "srednje",
            "rang": int(r["Rang slikara"] or 999),
        })
    # Samoprovera: četiri različita odgovora, slika postoji, nema ćirilice ni engleskog „The …”.
    for p in pitanja:
        assert len(set(p["ponude"])) == 4, p["id"]
        assert os.path.exists(os.path.join(folder, p["id"][2:] + ".webp")), p["id"]
        assert not any("Ѐ" <= c <= "ӿ" for c in p["naziv"]), p["id"]
        assert not p["naziv"].startswith("The "), p["id"]
    izlaz = os.path.join(REPO, "src", "lib", "igre", "slikari.json")
    with open(izlaz, "w", encoding="utf-8") as f:
        json.dump(pitanja, f, ensure_ascii=False, separators=(",", ":"))
    print(len(pitanja), "pitanja →", izlaz)


if __name__ == "__main__":
    main(sys.argv[1])
