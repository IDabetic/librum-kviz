#!/usr/bin/env python3
"""
Zvuci aplikacije (vlasnik 03.11.2026): isečci iz zvukova koje je vlasnik preuzeo + sintetizovani ostali.

Preuzeti fajlovi traju 10–15 s (generator pravi nizove), pa se uzima jedan čist deo (IZRECI: od, trajanje, utišavanje).
Ostali se prave ovde, bez AI, da budu naši i ponovljivi (SINTEZA). Svi idu u mobile/zvuci/*.m4a (AAC, mono, 44,1 kHz),
ujednačeni na istu jačinu (RMS −18 dBFS, vrh najviše −1 dBFS); jačinu po mestu dalje bira kod (Zvuk.pusti jacina:).

Upotreba: python3 alati/zvuci.py <folder sa preuzetim .mp3> mobile/zvuci
"""
import subprocess, sys, tempfile
from pathlib import Path

import numpy as np
import scipy.io.wavfile as wav
import scipy.signal as sg

SR = 44100
CILJ_RMS_DB = -18.0
NAJVISI_VRH = 10 ** (-1 / 20)

# Delovi izvora u kojima GOVORI glas (generator na kraju naglas čita opis zvuka). Nađeno detektorom glasa
# (Silero VAD) i prepoznavanjem govora (faster-whisper), 03.11.2026; isečak ne sme biti bliže od RAZMAK_OD_GOVORA.
GOVOR = {
    "heavy impact": [(6.42, 8.21)],
    "lose sound": [(12.18, 15.05)],
    "magic sparkle": [(12.08, 15.05)],
    "retreat whoosh": [(10.1, 12.5)],
}
RAZMAK_OD_GOVORA = 0.4

# ime u aplikaciji: (početak naziva preuzetog fajla, od [s], trajanje [s], utišavanje na kraju [s])
IZRECI = {
    "uzbuna": ("alarm horn", 0.0, 1.9, 0.3),
    "pojacanja": ("coins reward", 0.0, 2.0, 0.5),
    "prestonica_pala": ("heavy impact", 8.7, 2.0, 0.9),
    "karta_odigrana": ("karta_odigrana", 4.45, 0.55, 0.15),
    "pomoc_vojske": ("magic sparkle", 0.2, 1.4, 0.5),
    "obavestenje": ("ping", 0.0, 1.2, 0.5),
    "povlacenje": ("retreat whoosh", 1.15, 0.85, 0.35),
    "novi_krug": ("soft gong", 0.0, 2.4, 1.0),
    "izbor_drzave": ("soft pop", 1.64, 0.25, 0.1),
    "vojska_stavi": ("wooden click", 2.67, 0.2, 0.08),
    "bot_osvaja": ("wooden click", 7.49, 0.2, 0.08),
    "tvoj_potez": ("your turn", 0.0, 1.3, 0.5),
}


def t(trajanje):
    return np.arange(int(SR * trajanje)) / SR


def anvelopa(n, napad=0.005, opadanje=0.3):
    """Brz napad pa eksponencijalno opadanje (opadanje = vreme do −60 dB)."""
    x = np.arange(n) / SR
    return np.minimum(1, x / max(napad, 1e-4)) * np.exp(-x * 6.9 / opadanje)


def ton(f, trajanje, opadanje=None, harmonici=(1,), talas="sin"):
    x = t(trajanje)
    s = np.zeros_like(x)
    for i, h in enumerate(harmonici):
        faza = 2 * np.pi * f * (i + 1) * x
        s += h * (np.sin(faza) if talas == "sin" else sg.square(faza) if talas == "sq" else sg.sawtooth(faza))
    return s * anvelopa(len(x), opadanje=opadanje or trajanje)


def klizni(f0, f1, trajanje, opadanje=None):
    """Ton koji klizi od f0 do f1 (eksponencijalno)."""
    x = t(trajanje)
    f = f0 * (f1 / f0) ** (x / trajanje)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * anvelopa(len(x), opadanje=opadanje or trajanje)


def sum_(trajanje, nisko=None, visoko=None):
    s = np.random.default_rng(7).standard_normal(int(SR * trajanje))
    if nisko and visoko:
        s = sg.sosfilt(sg.butter(4, [nisko, visoko], "bandpass", fs=SR, output="sos"), s)
    elif visoko:
        s = sg.sosfilt(sg.butter(4, visoko, "lowpass", fs=SR, output="sos"), s)
    return s


def niz(*delovi):
    """Delovi (signal, početak [s]) složeni u jedan signal."""
    duzina = max(int(p * SR) + len(s) for s, p in delovi)
    out = np.zeros(duzina)
    for s, p in delovi:
        out[int(p * SR):int(p * SR) + len(s)] += s
    return out


def bubanj(f=70, trajanje=0.6):
    telo = klizni(f * 2.2, f, trajanje, opadanje=trajanje * 0.8)
    udar = sum_(0.08, visoko=2500) * anvelopa(int(SR * 0.08), opadanje=0.06) * 0.6
    return niz((telo, 0), (udar, 0))


def gong(f=110, trajanje=2.6):
    # Negarmonijski delovi daju metalni zvuk; viši brže opadaju.
    delovi = [(1, 1.0, 1.0), (1.48, 0.6, 0.7), (2.09, 0.45, 0.5), (2.76, 0.3, 0.35), (3.4, 0.2, 0.25)]
    x = t(trajanje)
    s = sum(a * np.sin(2 * np.pi * f * r * x + r) * anvelopa(len(x), napad=0.01, opadanje=trajanje * d) for r, a, d in delovi)
    return s * (1 + 0.15 * np.sin(2 * np.pi * 3.5 * x))


def truba(f, trajanje):
    """Limeni ton: testerasti talas kroz niski filter, mekan napad."""
    s = ton(f, trajanje, talas="saw", harmonici=(1, 0.3))
    s = sg.sosfilt(sg.butter(2, min(f * 6, 8000), "lowpass", fs=SR, output="sos"), s)
    x = t(trajanje)
    return s * np.minimum(1, x / 0.03) * np.minimum(1, (trajanje - x) / 0.08)


def arpedjo(frekvencije, korak, trajanje_note, opadanje, harmonici=(1, 0.4, 0.15)):
    return niz(*[(ton(f, trajanje_note, opadanje=opadanje, harmonici=harmonici), i * korak) for i, f in enumerate(frekvencije)])


C4, D4, E4, F4, G4, A4, B4 = 261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9
C5, E5, G5, C6 = 523.3, 659.3, 784.0, 1046.5

SINTEZA = {
    # Bot kreće u napad: dva udarca ratnog bubnja.
    "bot_napada": lambda: niz((bubanj(68), 0), (bubanj(62), 0.22)),
    # Dobijena karta: kratko šuštanje papira i tap.
    "karta_dobijena": lambda: niz((sum_(0.22, 1500, 7000) * np.linspace(0, 1, int(SR * 0.22)) ** 2 * 0.5, 0),
                                  (sum_(0.05, 800, 4000) * anvelopa(int(SR * 0.05), opadanje=0.04), 0.2)),
    # Savez: dva tona naviše (kvarta), topla zvona.
    "savez": lambda: arpedjo([G4, C5], 0.13, 0.7, 0.6),
    # Izdaja: niski disonantni udar (triton) uz šum.
    "izdaja": lambda: niz((ton(98, 1.0, opadanje=0.9, harmonici=(1, 0.5, 0.3), talas="saw") * 0.6, 0),
                          (ton(138.6, 1.0, opadanje=0.9, harmonici=(1, 0.5), talas="saw") * 0.5, 0),
                          (sum_(0.15, visoko=1200) * anvelopa(int(SR * 0.15), opadanje=0.12) * 0.6, 0)),
    # Brza poruka: mehurić (kratko klizanje naviše).
    "poruka": lambda: klizni(500, 1300, 0.12, opadanje=0.12),
    # Događaj na kontinentu: dubok gong.
    "dogadjaj": lambda: gong(82, 2.8),
    # Čudo sveta: kratka fanfara (tri note + akord).
    "cudo": lambda: niz((truba(G4, 0.14), 0), (truba(C5, 0.14), 0.15), (truba(E5, 0.14), 0.3),
                        (truba(C5, 0.7) * 0.6 + np.pad(truba(E5, 0.7), 0)[:int(SR * 0.7)] * 0.5 + truba(G5, 0.7) * 0.4, 0.45)),
    # Tajna misija: duža pobednička fanfara.
    "misija": lambda: niz((truba(C5, 0.12), 0), (truba(C5, 0.12), 0.13), (truba(C5, 0.12), 0.26), (truba(G4, 0.35), 0.39),
                          (truba(A4, 0.35), 0.75), (truba(B4, 0.2), 1.11),
                          (truba(C5, 1.0) * 0.6 + truba(E5, 1.0) * 0.45 + truba(G5, 1.0) * 0.35, 1.32)),
    # Novi nivo: brz uzlazni arpeđo.
    "nivo_gore": lambda: arpedjo([C5, E5, G5, C6, E5 * 2], 0.07, 0.5, 0.45),
    # Niz dana: plamičak (šum koji raste kroz filter + pucketanje).
    "niz": lambda: niz((sum_(0.6, 300, 3000) * np.sin(np.linspace(0, np.pi, int(SR * 0.6))) ** 2 * 0.7, 0),
                       *[(sum_(0.01, 2000, 8000) * 0.8, 0.1 + i * 0.09) for i in range(5)]),
    # Izgubljen život: kratak pad tona.
    "zivot": lambda: klizni(600, 260, 0.28, opadanje=0.3),
    # Vešanje: slovo pogođeno (naviše) / promašeno (naniže).
    "slovo_da": lambda: niz((ton(880, 0.1, opadanje=0.1, harmonici=(1, 0.2)), 0), (ton(1320, 0.14, opadanje=0.14, harmonici=(1, 0.2)), 0.06)),
    "slovo_ne": lambda: klizni(320, 200, 0.18, opadanje=0.2),
    # Igrač ušao u sobu: ding-dong.
    "protivnik_usao": lambda: niz((ton(E5, 0.9, opadanje=0.8, harmonici=(1, 0.3, 0.1)), 0), (ton(C5, 1.0, opadanje=0.9, harmonici=(1, 0.3, 0.1)), 0.32)),
    # Isteklo vreme za pitanje: dva tona naniže, zujalica (stari isečak je imao nešto nalik glasu).
    "isteklo": lambda: niz((sg.sosfilt(sg.butter(2, 2200, "lowpass", fs=SR, output="sos"), ton(330, 0.22, opadanje=0.5, talas="saw")) * 0.8, 0),
                           (sg.sosfilt(sg.butter(2, 1800, "lowpass", fs=SR, output="sos"), ton(247, 0.45, opadanje=0.6, talas="saw")) * 0.8, 0.24)),
    # Još 5 sekundi (vlasnik 04.11 uveče: stari bip je bio tih i neprimetan): dvotonska sirena, 4 oštra udara
    # visoko-nisko, četvrtasti talas (najglasniji za istu jačinu) i jača ujednačena jačina (GLASNIJE).
    "pet_sekundi": lambda: niz(*[(sg.sosfilt(sg.butter(2, 5000, "lowpass", fs=SR, output="sos"),
                                             ton(f, 0.16, opadanje=0.5, harmonici=(1,), talas="sq")), i * 0.19)
                                 for i, f in enumerate([1319, 988, 1319, 988])]),
    # Niz pobeda (kombo): brzi uzlazni udarci sa zvoncem na kraju.
    "kombo": lambda: niz(*[(bubanj(90 + i * 25, 0.25), i * 0.09) for i in range(3)], (arpedjo([E5, G5, C6], 0.05, 0.5, 0.4), 0.27)),
    # Izgubljena država: tri tona naniže.
    "izgubio_drzavu": lambda: arpedjo([E4, D4, C4 * 0.94], 0.17, 0.5, 0.45, harmonici=(1, 0.5, 0.2)),
}


def izreci(fajl, od, trajanje, utisavanje):
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(fajl), "-ac", "1", "-ar", str(SR), tmp.name], check=True)
        _, x = wav.read(tmp.name)
    x = x.astype(np.float64) / 32768
    s = x[int(od * SR):int((od + trajanje) * SR)].copy()
    n = int(utisavanje * SR)
    if n:
        s[-n:] *= np.linspace(1, 0, n) ** 2
    s[:64] *= np.linspace(0, 1, 64)  # bez pucketanja na početku isečka
    return s


def ujednaci(s, cilj=CILJ_RMS_DB):
    aktivno = s[np.abs(s) > np.abs(s).max() * 0.05]
    rms = np.sqrt(np.mean(aktivno ** 2)) if len(aktivno) else 1e-6
    s = s * (10 ** (cilj / 20) / rms)
    vrh = np.abs(s).max()
    return s * (NAJVISI_VRH / vrh) if vrh > NAJVISI_VRH else s


# Upozorenja koja moraju da se čuju preko svega: jača ujednačena jačina (dBFS RMS).
GLASNIJE = {"pet_sekundi": -10.0}


def sacuvaj(s, put):
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        wav.write(tmp.name, SR, (ujednaci(s, GLASNIJE.get(Path(put).stem, CILJ_RMS_DB)) * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp.name, "-c:a", "aac", "-b:a", "96k", str(put)], check=True)


def _provera():
    s = ujednaci(np.sin(2 * np.pi * 440 * t(0.5)) * 0.01)
    assert abs(20 * np.log10(np.sqrt(np.mean(s ** 2))) - CILJ_RMS_DB) < 0.5
    assert np.abs(ujednaci(np.r_[np.zeros(100), 1.0, np.zeros(100)])).max() <= NAJVISI_VRH + 1e-9
    assert set(IZRECI).isdisjoint(SINTEZA), "isti zvuk i iz fajla i iz sinteze"
    for ime, (izvor, od, trajanje, _) in IZRECI.items():
        for a, b in GOVOR.get(izvor, []):
            assert od + trajanje + RAZMAK_OD_GOVORA <= a or od >= b + RAZMAK_OD_GOVORA, f"{ime}: isečak dira govor {a}–{b} s"


if __name__ == "__main__":
    _provera()
    ulaz, izlaz = Path(sys.argv[1]), Path(sys.argv[2])
    izlaz.mkdir(parents=True, exist_ok=True)
    for ime, (pocetak, od, trajanje, utis) in IZRECI.items():
        fajl = next(f for f in ulaz.iterdir() if f.name.lower().startswith(pocetak))
        sacuvaj(izreci(fajl, od, trajanje, utis), izlaz / f"{ime}.m4a")
        print("isečak", ime)
    for ime, napravi in SINTEZA.items():
        sacuvaj(napravi(), izlaz / f"{ime}.m4a")
        print("sinteza", ime)
