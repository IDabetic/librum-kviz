"""Ratnička podloga za video Osvajanja na sajtu: bubnjevi (sintetizovani) + zvuci iz igre u zadatim trenucima.

Upotreba: python3 alati/ratni-zvuk.py <trajanje_s> <izlaz.wav> [sekunda:zvuk ...]
Primer:   python3 alati/ratni-zvuk.py 50 /tmp/podloga.wav 0:uzbuna 24:novi_krug 44:prestonica_pala
Zvuci se čitaju iz mobile/zvuci/<ime>.m4a (ffmpeg).
"""
import subprocess, sys, wave
from pathlib import Path
import numpy as np

SR = 44100
TEMPO = 96  # udaraca u minuti: koračnica, ne žurka
ZVUCI = Path(__file__).resolve().parent.parent / "mobile" / "zvuci"


def bubanj(frekv: float, trajanje: float, jacina: float) -> np.ndarray:
    """Tom: sinus koji pada po visini + kratak šum za udar."""
    t = np.arange(int(SR * trajanje)) / SR
    ton = np.sin(2 * np.pi * frekv * (1 + 0.6 * np.exp(-t * 18)) * t) * np.exp(-t * 7)
    udar = np.random.default_rng(7).standard_normal(t.size) * np.exp(-t * 60) * 0.25
    return (ton + udar) * jacina


def podloga(sekundi: float) -> np.ndarray:
    out = np.zeros(int(SR * sekundi))
    takt = 60 / TEMPO
    # Obrazac na 8 udaraca: duboki tom na 1 i 5, srednji na 3 i 7, tihi na ostalim (koračnica).
    obrazac = [(55, 0.9), (110, 0.25), (82, 0.6), (110, 0.25), (55, 0.9), (110, 0.25), (82, 0.6), (98, 0.45)]
    i = 0
    while i * takt < sekundi - 0.5:
        f, j = obrazac[i % len(obrazac)]
        b = bubanj(f, 0.6, j)
        s = int(i * takt * SR)
        out[s:s + b.size] += b[: max(0, out.size - s)]
        i += 1
    return out * 0.5


def ucitaj(ime: str) -> np.ndarray:
    pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", str(ZVUCI / f"{ime}.m4a"), "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(pcm, np.int16).astype(np.float64) / 32768


def napravi(sekundi: float, dogadjaji: list[tuple[float, str]]) -> np.ndarray:
    out = podloga(sekundi)
    for kada, ime in dogadjaji:
        z = ucitaj(ime) * 0.9
        s = int(kada * SR)
        n = min(z.size, out.size - s)
        if n > 0:
            out[s:s + n] += z[:n]
    # Postepeno utišavanje na kraju i ograničenje vrha (bez pucketanja).
    kraj = int(SR * 1.5)
    out[-kraj:] *= np.linspace(1, 0, kraj)
    return out / max(1.0, np.abs(out).max() / 0.9)


def _provera():
    x = napravi(3, [])
    assert x.size == 3 * SR and np.abs(x).max() <= 0.9 + 1e-9 and np.abs(x).max() > 0.1


if __name__ == "__main__":
    _provera()
    sekundi = float(sys.argv[1])
    dogadjaji = [(float(a.split(":")[0]), a.split(":")[1]) for a in sys.argv[3:]]
    zvuk = (napravi(sekundi, dogadjaji) * 32767).astype(np.int16)
    with wave.open(sys.argv[2], "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(zvuk.tobytes())
    print("ok", sys.argv[2])
