#!/usr/bin/env python3
"""Ikonica aplikacije: tirkizna pozadina sa svetlom, žuti oblačić sa upitnikom, Bloop maskota.
Pravi iOS (1024, svetla i tamna), Android adaptivnu (prednji sloj 432) i stare mipmap ikone.
Primer: python3 alati/ikona/napravi-ikonu.py"""
import subprocess, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

KOREN = Path(__file__).resolve().parents[2]
BLOOP = Image.open(KOREN / "public/maskote/Bloop.png").convert("RGBA")
TEAL, TEAL_TAMNA, ZUTA, TINTA = (18, 144, 126), (11, 96, 84), (255, 216, 77), (21, 21, 21)


def oblacic(v):
    """Žuti oblačić sa upitnikom (SVG → PNG), veličine v×v."""
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{v}" height="{v}" viewBox="0 0 100 100">
      <path d="M50 6c24 0 42 15 42 34s-18 34-42 34c-4 0-8-.4-12-1.3L18 84l5-15C13 62 8 52 8 40 8 21 26 6 50 6z"
            fill="#FFD84D" stroke="#151515" stroke-width="4" stroke-linejoin="round"/>
      <text x="50" y="57" font-family="Arial Black, Helvetica, sans-serif" font-weight="900" font-size="46"
            text-anchor="middle" fill="#151515">?</text></svg>'''
    with tempfile.TemporaryDirectory() as d:
        s, p = Path(d) / "o.svg", Path(d) / "o.png"
        s.write_text(svg)
        subprocess.run(["rsvg-convert", "-w", str(v), "-h", str(v), str(s), "-o", str(p)], check=True)
        return Image.open(p).convert("RGBA")


def pozadina(v, tamna):
    """Radijalni sjaj gore levo, da ikonica ne bude ravna ploča."""
    osnova, svetlo = ((10, 22, 20), (18, 70, 62)) if tamna else (TEAL_TAMNA, (64, 196, 172))
    im = Image.new("RGBA", (v, v), osnova + (255,))
    sjaj = Image.new("L", (v, v), 0)
    ImageDraw.Draw(sjaj).ellipse((-v * 0.35, -v * 0.45, v * 1.0, v * 0.9), fill=255)
    sjaj = sjaj.filter(ImageFilter.GaussianBlur(v * 0.18))
    im.paste(Image.new("RGBA", (v, v), svetlo + (255,)), (0, 0), sjaj)
    return im


def scena(v, tamna=False, providno=False):
    """Oblačić gore desno, maskota dole u sredini; sve unutar sigurne zone (iOS seče uglove, Android krug)."""
    im = Image.new("RGBA", (v, v), (0, 0, 0, 0)) if providno else pozadina(v, tamna)
    o = oblacic(int(v * 0.44)).rotate(-8, resample=Image.BICUBIC, expand=True)
    im.alpha_composite(o, (int(v * 0.50), int(v * 0.08)))
    b = BLOOP.crop(BLOOP.getbbox())
    s = int(v * 0.70)
    b = b.resize((s, int(b.height * s / b.width)), Image.LANCZOS)
    senka = Image.new("RGBA", b.size, (0, 0, 0, 0))
    senka.putalpha(b.getchannel("A").point(lambda a: int(a * 0.35)))
    senka = senka.filter(ImageFilter.GaussianBlur(v * 0.015))
    # Telo prelazi donju ivicu (izviruje), osim na providnom Android sloju gde maska seče krug.
    x, y = (v - b.width) // 2, v - b.height + (int(v * 0.05) if not providno else -int(v * 0.02))
    im.alpha_composite(senka, (x, y + int(v * 0.015)))
    im.alpha_composite(b, (x, y))
    return im


def sacuvaj():
    ios = KOREN / "mobile/ios/LibrumKviz/Assets.xcassets/AppIcon.appiconset"
    scena(1024).convert("RGB").save(ios / "ikona-1024.png")
    scena(1024, tamna=True).convert("RGB").save(ios / "ikona-1024-tamna.png")
    res = KOREN / "mobile/android/app/src/main/res"
    # Adaptivna: prednji sloj 108dp, sadržaj u sredini 72dp (66%) da ga maska ne odseče.
    for ime, d in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        sadrzaj = scena(int(d * 0.74), providno=True)
        prednji = Image.new("RGBA", (d, d), (0, 0, 0, 0))
        prednji.alpha_composite(sadrzaj, ((d - sadrzaj.width) // 2, (d - sadrzaj.height) // 2))
        prednji.save(res / f"mipmap-{ime}/ic_launcher_foreground.png")
        pozadina(d, False).save(res / f"mipmap-{ime}/ic_launcher_background.png")
        l = d * 48 // 108
        scena(l).save(res / f"mipmap-{ime}/ic_launcher.png")
    scena(512).convert("RGB").save(KOREN / "alati/ikona/play-512.png")


if __name__ == "__main__":
    sacuvaj()
