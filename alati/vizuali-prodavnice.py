"""Vizuali za App Store i Google Play: tekst levo, telefon sa ekranom aplikacije desno (vlasnik 04.11.2026).

Ažurirano: 04.11.2026 · verzija 2 (Play 16:9)

Ulaz: mobile/snimci/iphone/*.png (iPhone 17 Pro Max, 1320×2868). Izlaz:
- mobile/snimci/vizuali/appstore/NN.png  2868×1320 (iPhone 6.9", vodoravno; App Store prima najviše 10)
- mobile/snimci/vizuali/play/NN.png      2560×1440 (16:9, Play traži 16:9 ili 9:16; prima najviše 8)
Upotreba (iz korena repoa): python3 alati/vizuali-prodavnice.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

KOREN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNIMCI = os.path.join(KOREN, "mobile", "snimci", "iphone")
FONT_NASLOV = os.path.join(KOREN, "mobile", "fontovi", "ArchivoBlack-Regular.ttf")
FONT_TEKST = os.path.join(KOREN, "mobile", "fontovi", "SpaceGrotesk.ttf")
TINTA, BELA = "#151515", "#FFFFFF"

# (ekran, oznaka, naslov, podnaslov, pozadina, boja teksta) — redosled je redosled u prodavnici.
VIZUALI = [
    ("02-osvajanje-mapa", "OSVAJANJE SVETA", "Osvoji svet\nznanjem", "171 država, saveznici i tajna misija.\nSvaki napad je bitka pitanja.", "#12907E", BELA),
    ("04-pitanje-moc-vojske", "ŠEST VOJSKI", "Svaka vojska,\nsvoja moć", "Siguran udar, Štit, Vreme stoji,\nPola-pola, Juriš ili Tačan odgovor.", "#6D4BC9", BELA),
    ("03-bitka", "BITKA", "Napadni.\nOdbrani se.", "Bitka su pitanja: tačniji i brži\nosvaja državu.", "#FFD84D", TINTA),
    ("01-pocetna", "LIBRUM KVIZ", "Kviz o svemu,\nkad god", "Osvajanje sveta i šest igara znanja.\nViše od 160.000 pitanja.", "#F3F0E6", TINTA),
    ("09-slikari", "SLIKARI", "Ko je naslikao\novo delo?", "1.167 slika, od Leonarda do Pikasa.", "#FF5FA2", TINTA),
    ("07-igraj-sa-drugima", "IGRAJ SA DRUGIMA", "Od 2 do 8\nigrača", "Svako za sebe ili timovi po dvoje,\nprotiv prijatelja ili računara.", "#6EC3F2", TINTA),
    ("08-tabela-uzivo", "UŽIVO", "Ista pitanja,\nisto vreme", "Tabela se menja dok igraš.", "#F4A33C", TINTA),
    ("06-brzi-kviz", "BRZI KVIZ", "60 sekundi.\nTačno ili ne?", "Niz tačnih množi poene,\nzavršnica ih duplira.", "#151515", BELA),
    ("11-rang-lista", "RANG LISTA", "Popni se\nna vrh", "Rang liste po igri: dan, nedelja,\nmesec i godina.", "#12907E", BELA),
    ("10-vesanje", "VEŠANJE", "Pogodi reč\nslovo po slovo", "Srpska azbuka, nagoveštaj\ni pet života.", "#FFD84D", TINTA),
    ("05-osvajanje-svet", "SVET SE MENJA", "Granice se\npomeraju", "Posle svake bitke mapa je\ndrugačija.", "#6D4BC9", BELA),
    ("12-igraci", "ZAJEDNICA", "Igraj sa\nprijateljima", "Prati igrače, izazovi ih na duel\ni podeli rezultat.", "#FF5FA2", TINTA),
]


def telefon(ekran: Image.Image, visina: int) -> Image.Image:
    """Ekran u telefonu: crni okvir, zaobljeni uglovi, ostrvo na vrhu, meka senka."""
    sirina = round(visina * ekran.width / ekran.height)
    okvir = round(visina * 0.022)
    radijus = round(visina * 0.085)
    W, H = sirina + 2 * okvir, visina + 2 * okvir
    senka_pad = round(visina * 0.06)
    platno = Image.new("RGBA", (W + 2 * senka_pad, H + 2 * senka_pad), (0, 0, 0, 0))
    senka = Image.new("L", platno.size, 0)
    ImageDraw.Draw(senka).rounded_rectangle((senka_pad, senka_pad + okvir, senka_pad + W, senka_pad + H + okvir), radijus + okvir, fill=110)
    platno.putalpha(senka.filter(ImageFilter.GaussianBlur(senka_pad // 2)))
    telo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(telo).rounded_rectangle((0, 0, W - 1, H - 1), radijus + okvir, fill="#0E0E0E")
    slika = ekran.convert("RGB").resize((sirina, visina), Image.LANCZOS)
    maska = Image.new("L", (sirina, visina), 0)
    ImageDraw.Draw(maska).rounded_rectangle((0, 0, sirina - 1, visina - 1), radijus, fill=255)
    telo.paste(slika, (okvir, okvir), maska)
    ostrvo_s, ostrvo_v = round(sirina * 0.28), round(visina * 0.033)
    x0, y0 = okvir + (sirina - ostrvo_s) // 2, okvir + round(visina * 0.012)
    ImageDraw.Draw(telo).rounded_rectangle((x0, y0, x0 + ostrvo_s, y0 + ostrvo_v), ostrvo_v // 2, fill="#0E0E0E")
    platno.alpha_composite(telo, (senka_pad, senka_pad))
    return platno


def vizual(ekran: str, oznaka: str, naslov: str, podnaslov: str, pozadina: str, boja: str, W: int, H: int) -> Image.Image:
    img = Image.new("RGB", (W, H), pozadina)
    d = ImageDraw.Draw(img)
    # Veliki blagi krug iza telefona (isti motiv kao kartice igara u aplikaciji).
    krug = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = round(H * 0.62)
    cx, cy = round(W * 0.73), round(H * 0.55)
    ImageDraw.Draw(krug).ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 46))
    img.paste(krug, (0, 0), krug)
    tel = telefon(Image.open(os.path.join(SNIMCI, ekran + ".png")), round(H * 0.88))
    img.paste(tel, (round(W * 0.73) - tel.width // 2, round(H * 0.5) - tel.height // 2), tel)
    levo = round(W * 0.065)
    f_oznaka = ImageFont.truetype(FONT_NASLOV, round(H * 0.032))
    f_naslov = ImageFont.truetype(FONT_NASLOV, round(H * 0.125))
    f_tekst = ImageFont.truetype(FONT_TEKST, round(H * 0.052))
    y = round(H * 0.25)
    d.text((levo, y), oznaka, font=f_oznaka, fill=boja)
    y += round(H * 0.075)
    d.multiline_text((levo, y), naslov, font=f_naslov, fill=boja, spacing=round(H * 0.012))
    y = d.multiline_textbbox((levo, y), naslov, font=f_naslov, spacing=round(H * 0.012))[3] + round(H * 0.05)
    d.multiline_text((levo, y), podnaslov, font=f_tekst, fill=boja, spacing=round(H * 0.016))
    # Tekst ne sme da uđe pod telefon.
    assert d.multiline_textbbox((levo, y), podnaslov, font=f_tekst)[2] < round(W * 0.73) - tel.width // 2 + round(H * 0.06), ekran
    return img


def main():
    for folder, (W, H), najvise in (("appstore", (2868, 1320), 10), ("play", (2560, 1440), 8)):
        izlaz = os.path.join(KOREN, "mobile", "snimci", "vizuali", folder)
        os.makedirs(izlaz, exist_ok=True)
        for i, v in enumerate(VIZUALI, 1):
            vizual(*v, W, H).save(os.path.join(izlaz, f"{i:02d}.png"))
        print(folder, len(VIZUALI), "vizuala (u prodavnicu ide prvih", najvise, ")")


if __name__ == "__main__":
    main()
