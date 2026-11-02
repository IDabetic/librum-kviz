"""Kviz „Slikari” iz tabele vlasnika (kviz-baze/kviz-slikari.xlsx) u JSON za aplikacije.

Slike se ne pakuju u aplikaciju (588 MB): ostaje link na Wikimedia Commons, uz manju
širinu za telefon. Ponovo pokrenuti kad se tabela dopuni.

Upotreba:
  ../Claude/kviz-baze/alati/.venv/bin/python -I alati/slikari-u-json.py \
      ../Claude/kviz-baze/kviz-slikari.xlsx src/lib/igre/slikari.json
"""
import json
import sys

from openpyxl import load_workbook

SIRINA_SLIKE = 800
KOLONE = ["rang", "fajl", "link", "naziv", "naziv_en", "tacan", "n1", "n2", "n3", "godina", "pravac", "zemlja", "muzej", "tezina", "wikidata"]


def red_u_pitanje(r):
    d = dict(zip(KOLONE, r))
    if not d["link"] or not d["tacan"] or not all(d[k] for k in ("n1", "n2", "n3")):
        return None
    ponude = [d["tacan"], d["n1"], d["n2"], d["n3"]]
    if len(set(ponude)) != 4:
        return None
    return {
        "id": "s-" + d["wikidata"].rsplit("/", 1)[-1],
        "naziv": d["naziv"] or d["naziv_en"],
        "slika": d["link"].replace("http://", "https://", 1).replace("?width=1024", f"?width={SIRINA_SLIKE}"),
        "ponude": ponude,
        "godina": str(d["godina"] or ""),
        "pravac": d["pravac"] or "",
        "zemlja": d["zemlja"] or "",
        "muzej": d["muzej"] or "",
        "tezina": d["tezina"] or "srednje",
        "rang": int(d["rang"] or 999),
    }


def main(ulaz, izlaz):
    wb = load_workbook(ulaz, read_only=True)
    pitanja, vidjeno = [], set()
    for ws in wb.worksheets[1:]:
        for r in list(ws.iter_rows(values_only=True))[1:]:
            p = red_u_pitanje(r)
            if p and p["id"] not in vidjeno:
                vidjeno.add(p["id"])
                pitanja.append(p)
    assert pitanja, "tabela nema nijedno ispravno pitanje"
    with open(izlaz, "w", encoding="utf-8") as f:
        json.dump(pitanja, f, ensure_ascii=False, separators=(",", ":"))
    print(len(pitanja), "pitanja →", izlaz)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
