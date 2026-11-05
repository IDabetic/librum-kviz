"""Kviz „Slikari” iz tabele vlasnika (kviz-baze/kviz-slikari.xlsx) u JSON za aplikacije.

Slike se ne pakuju u aplikaciju (588 MB): ostaje link na Wikimedia Commons, uz manju
širinu za telefon. Delo bez preuzete slike (kolona „Slika (fajl)” ne postoji na disku)
postaje tekstualno pitanje. Nazivi, imena i muzeji idu na srpski kroz
alati/slikari-prevod.tsv, alati/slikari-muzeji.tsv i IMENA ispod; vlasnikova tabela se ne menja.
Ponovo pokrenuti kad se tabela dopuni.

Upotreba:
  ../Claude/kviz-baze/alati/.venv/bin/python -I alati/slikari-u-json.py \
      ../Claude/kviz-baze/kviz-slikari.xlsx src/lib/igre/slikari.json
"""
import json
import os
import sys

from openpyxl import load_workbook

SIRINA_SLIKE = 800
# Imena koja u tabeli nisu preslovljena (pravopis: izgovor u izvornom jeziku).
IMENA = {
    "Aleksandr Deyneka": "Aleksandar Dejneka", "Almrita Šer-Gil": "Amrita Šer-Gil",
    "Amadeo de Souza Cardoso": "Amadeo de Souza Kardozo", "Auguste Renoir": "Ogist Renoar",
    "Candido Portinari": "Kandido Portinari", "Chang Ta-chien": "Džang Daćijen",
    "Georges Seurat": "Žorž Sera", "Gerard ter Borch": "Gerard ter Borh", "Gu Kaizhi": "Gu Kaiđi",
    "Guido Reni": "Gvido Reni", "Gustave Moreau": "Gistav Moro", "Jacques-Louis David": "Žak-Luj David",
    "Jamini Roy": "Đamini Roj", "Jean-Honoré Fragonard": "Žan-Onore Fragonar",
    "Jean-Michel Basquiat": "Žan-Mišel Baskija", "Joaquín Sorolla": "Hoakin Sorolja",
    "Joaquín Torres-García": "Hoakin Tores-Garsija", "José Clemente Orozco": "Hose Klemente Orosko",
    "Kitagawa Utamaro": "Kitagava Utamaro", "Lee Ufan": "Li Ufan", "Luca Giordano": "Luka Đordano",
    "Nandalal Bose": "Nandalal Bos", "Odilon Redon": "Odilon Redon", "Ogata Kōrin": "Ogata Korin",
    "Oswaldo Guayasamín": "Osvaldo Gvajasamin", "Park Su-geun": "Pak Su-gun",
    "Peter Paul Rubens": "Peter Paul Rubens", "Pierre Puvis de Chavannes": "Pjer Pivi de Šavan",
    "Qi Baishi": "Ći Baiši", "René Magritte": "Rene Magrit", "Robert Delaunay": "Rober Delone",
    "Rufino Tamayo": "Rufino Tamajo", "Vincent van Gogh": "Vinsent van Gog", "Wifredo Lam": "Vifredo Lam",
    "Xu Beihong": "Sju Bejhung", "Tamara De Lempicka": "Tamara de Lempicka", "Rahel Rojsh": "Rahel Rojs",
}
PRAVCI = {"Ukiyo-e": "Ukijo-e", "De Stijl": "De Stajl", "Sumi-e": "Sumi-e"}
KORENI = os.path.dirname(os.path.abspath(__file__))


def ucitaj_tsv(ime):
    with open(os.path.join(KORENI, ime), encoding="utf-8") as f:
        # Red bez druge kolone znači „ne prikazuj” (prazna vrednost).
        return dict((l.rstrip("\n").split("\t", 1) + [""])[:2] for l in f if l.strip() and not l.startswith("#"))


KOLONE = ["rang", "fajl", "link", "naziv", "naziv_en", "tacan", "n1", "n2", "n3", "godina", "pravac", "zemlja", "muzej", "tezina", "wikidata"]


def red_u_pitanje(r, nazivi, muzeji, koren):
    d = dict(zip(KOLONE, r))
    if not d["tacan"] or not all(d[k] for k in ("n1", "n2", "n3")):
        return None
    ponude = [IMENA.get(x, x) for x in (d["tacan"], d["n1"], d["n2"], d["n3"])]
    if len(set(ponude)) != 4:
        return None
    q = d["wikidata"].rsplit("/", 1)[-1]
    ima_sliku = bool(d["link"] and d["fajl"] and os.path.exists(os.path.join(koren, d["fajl"])))
    return {
        "id": "s-" + q,
        "naziv": nazivi.get(q) or d["naziv"] or d["naziv_en"],
        "slika": d["link"].replace("http://", "https://", 1).replace("?width=1024", f"?width={SIRINA_SLIKE}") if ima_sliku else "",
        "ponude": ponude,
        "godina": str(d["godina"] or ""),
        "pravac": PRAVCI.get(d["pravac"], d["pravac"] or ""),
        "zemlja": d["zemlja"] or "",
        "muzej": muzeji.get(d["muzej"], d["muzej"] or ""),
        "tezina": d["tezina"] or "srednje",
        "rang": int(d["rang"] or 999),
    }


def main(ulaz, izlaz):
    wb = load_workbook(ulaz, read_only=True)
    nazivi, muzeji = ucitaj_tsv("slikari-prevod.tsv"), ucitaj_tsv("slikari-muzeji.tsv")
    # Putanje slika u tabeli su relativne prema folderu tabele (kviz-baze/).
    koren = os.path.dirname(os.path.abspath(ulaz))
    pitanja, vidjeno = [], set()
    for ws in wb.worksheets[1:]:
        for r in list(ws.iter_rows(values_only=True))[1:]:
            p = red_u_pitanje(r, nazivi, muzeji, koren)
            if p and p["id"] not in vidjeno:
                vidjeno.add(p["id"])
                pitanja.append(p)
    # Bez slike ostaje samo naziv: „Bez naziva”, „Autoportret” i ostali koji se ponavljaju nemaju odgovor.
    broj = {}
    for p in pitanja:
        broj[p["naziv"]] = broj.get(p["naziv"], 0) + 1
    pitanja = [p for p in pitanja if p["slika"] or (broj[p["naziv"]] == 1 and not p["naziv"].startswith(("Bez naziva", "Nepoznat")))]
    assert pitanja, "tabela nema nijedno ispravno pitanje"
    # Samoprovera: nijedan naziv ne sme ostati isti kao engleski, osim imena koja se ne prevode.
    engleski = [p for p in pitanja if not any(c in p["naziv"] for c in "čćžšđČĆŽŠĐ") and p["naziv"].lower().split()[:1] in (["the"], ["a"], ["portrait"])]
    assert not engleski, f"ostali engleski nazivi: {[p['naziv'] for p in engleski][:5]}"
    with open(izlaz, "w", encoding="utf-8") as f:
        json.dump(pitanja, f, ensure_ascii=False, separators=(",", ":"))
    print(len(pitanja), "pitanja →", izlaz)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
