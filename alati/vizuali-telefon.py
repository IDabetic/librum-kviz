"""Uspravni vizuali za App Store i Google Play: tekst gore, telefon ispod (vlasnik 05.11.2026: „samo telefon”, sa Karijeristom).

Ažurirano: 05.11.2026 · verzija 1

Ulaz: mobile/snimci/iphone/*.png (iPhone 17 Pro Max, 1320×2868). Izlaz:
- mobile/snimci/vizuali/telefon-appstore/NN.png  1320×2868 (iPhone 6.9", uspravno; App Store prima najviše 10)
- mobile/snimci/vizuali/telefon-play/NN.png      1440×2560 (9:16; Play prima najviše 8)
Upotreba (iz korena repoa): python3 alati/vizuali-telefon.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from importlib import import_module

_stari = import_module("vizuali-prodavnice")  # telefon(): okvir, ostrvo i senka, isti kao vodoravni vizuali
telefon, KOREN, SNIMCI = _stari.telefon, _stari.KOREN, _stari.SNIMCI
FONT_NASLOV, FONT_TEKST = _stari.FONT_NASLOV, _stari.FONT_TEKST
TINTA, BELA = "#151515", "#FFFFFF"

# (ekran, oznaka, naslov, podnaslov, pozadina, boja teksta) — redosled je redosled u prodavnici.
VIZUALI = [
    ("01-pocetna", "LIBRUM KVIZ", "Kviz o svemu,\nkad god", "Osvajač, Karijerista i još šest igara.\nViše od 165.000 pitanja na srpskom.", "#F3F0E6", TINTA),
    ("02-osvajanje-mapa", "OSVAJAČ", "Osvoji svet\nznanjem", "171 država, saveznici i tajne misije.\nSvaki napad je bitka pitanja.", "#12907E", BELA),
    ("13-karijerista", "KARIJERISTA", "Od juniora do\nsvog nebodera", "Probni rad, plata, ugled\ni na kraju tvoja firma.", "#3D63D6", BELA),
    ("14-grad", "GRAD FIRMI", "Svaka zgrada je\nnečija firma", "Zaposli se kod drugog igrača\nili mu preuzmi firmu u duelu.", "#FFD84D", TINTA),
    ("17-runda", "RUNDA", "Deset pitanja,\nprava plata", "Pitanja iz struke i opšteg znanja.\nPomoć kad zapne.", "#6EC3F2", TINTA),
    ("03-bitka", "BITKA", "Napadni.\nOdbrani se.", "Tačniji i brži osvaja državu.", "#6D4BC9", BELA),
    ("09-slikari", "SLIKARI", "Ko je naslikao\novo delo?", "1.167 slika, od Leonarda do Pikasa.", "#FF5FA2", TINTA),
    ("12-igraci", "ZAJEDNICA", "Igraj sa\nprijateljima", "Ko je na mreži, izazovi na duel\ni podeli rezultat.", "#F4A33C", TINTA),
    ("11-rang-lista", "RANG LISTA", "Popni se\nna vrh", "Rang liste po igri: dan, nedelja,\nmesec i godina.", "#12907E", BELA),
    ("07-igraj-sa-drugima", "IGRAJ SA DRUGIMA", "Od 2 do 8\nigrača", "Svako za sebe ili timovi,\nprotiv prijatelja ili računara.", "#151515", BELA),
]


def vizual(ekran: str, oznaka: str, naslov: str, podnaslov: str, pozadina: str, boja: str, W: int, H: int) -> Image.Image:
    img = Image.new("RGB", (W, H), pozadina)
    d = ImageDraw.Draw(img)
    levo = round(W * 0.08)
    y = round(H * 0.055)
    f_oznaka = ImageFont.truetype(FONT_NASLOV, round(W * 0.034))
    f_naslov = ImageFont.truetype(FONT_NASLOV, round(W * 0.098))
    f_tekst = ImageFont.truetype(FONT_TEKST, round(W * 0.040))
    d.text((levo, y), oznaka, font=f_oznaka, fill=boja)
    y += round(W * 0.075)
    d.multiline_text((levo, y), naslov, font=f_naslov, fill=boja, spacing=round(W * 0.012))
    y = d.multiline_textbbox((levo, y), naslov, font=f_naslov, spacing=round(W * 0.012))[3] + round(W * 0.035)
    d.multiline_text((levo, y), podnaslov, font=f_tekst, fill=boja, spacing=round(W * 0.016))
    kraj_teksta = d.multiline_textbbox((levo, y), podnaslov, font=f_tekst, spacing=round(W * 0.016))
    assert kraj_teksta[2] < W - levo, (ekran, "tekst preširok")
    # Telefon zauzima ostatak visine i izlazi ispod donje ivice (kao da ga držiš), da ekran bude što veći.
    vrh = kraj_teksta[3] + round(H * 0.035)
    tel = telefon(Image.open(os.path.join(SNIMCI, ekran + ".png")), round((H - vrh) * 1.08))
    img.paste(tel, ((W - tel.width) // 2, vrh - round(tel.height * 0.03)), tel)
    return img


def main():
    for folder, (W, H), najvise in (("telefon-appstore", (1320, 2868), 10), ("telefon-play", (1440, 2560), 8)):
        izlaz = os.path.join(KOREN, "mobile", "snimci", "vizuali", folder)
        os.makedirs(izlaz, exist_ok=True)
        for i, v in enumerate(VIZUALI[:najvise], 1):
            vizual(*v, W, H).save(os.path.join(izlaz, f"{i:02d}.png"))
        print(folder, min(len(VIZUALI), najvise), "vizuala")


if __name__ == "__main__":
    main()
