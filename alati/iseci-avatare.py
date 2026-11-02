"""Iseca Knjigopolis listove avatara (public/avatars/sheetN.jpg, mreža 9×9) u pojedinačne
slike za kviz: veb (public/avatari), iOS i Android ih čitaju iz istog foldera.
Oznaka avatara je ista kao na Knjigopolisu: "sN:red:kolona" → fajl sN_red_kolona.jpg.

Upotreba: python3 alati/iseci-avatare.py ../Knjigopolis/public/avatars public/avatari
"""
import json
import sys
from pathlib import Path

from PIL import Image

VELICINA = 160
ZUM = 1.08  # isto kao avatar-sheet.ts: skriva tanak rub susednih ćelija

def pozicije(list_id):
    sve = [(r, c) for r in range(9) for c in range(9)]
    if list_id in (1, 3, 4):
        return [(r, c) for r, c in sve if r <= 4 or c >= 4]
    if list_id == 2:
        return [(r, c) for r, c in sve if not (3 <= r <= 5 and 3 <= c <= 5)]
    return [(r, c) for r, c in sve if r >= 4 or c <= 4]  # list 5

def main(ulaz, izlaz):
    izlaz = Path(izlaz)
    oznake = []
    for n in range(1, 6):
        slika = Image.open(Path(ulaz) / ("sheet.jpg" if n == 1 else f"sheet{n}.jpg")).convert("RGB")
        w, h = slika.size
        cw, ch = w / 9, h / 9
        for r, c in pozicije(n):
            m = (1 - 1 / ZUM) / 2
            kutija = (c * cw + cw * m, r * ch + ch * m, (c + 1) * cw - cw * m, (r + 1) * ch - ch * m)
            slika.crop(tuple(round(x) for x in kutija)).resize((VELICINA, VELICINA), Image.LANCZOS) \
                .save(izlaz / f"s{n}_{r}_{c}.jpg", quality=82, optimize=True)
            oznake.append(f"s{n}:{r}:{c}")
    (izlaz / "spisak.json").write_text(json.dumps(oznake))
    print(len(oznake), "avatara")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
