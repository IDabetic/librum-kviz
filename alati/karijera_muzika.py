#!/usr/bin/env python3
"""
Muzika i zvuci Karijere (vlasnik 05.11.2026): vlasnik kupio pakete (AudioJungle/Freepik, zip u Downloads),
ovde se biraju fajlovi, seku kratki delovi i ujednačava jačina; kasa i zvono se sintetišu (paket „cash register”
je muzička petlja sa udaraljkama, ne jedan zvuk kase; zvono vlasnik nije našao).

Petlje se NE seku (autori su ih pravili da se ponavljaju), samo dobijaju stalno pojačanje (bez kompresije,
da spoj kraja i početka ostane čist). Muzika na −20 LUFS, kratki zvuci na −16 LUFS; jačinu po mestu bira kod.

Upotreba: python3 alati/karijera_muzika.py <folder sa raspakovanim paketima> mobile/zvuci
"""
import json, subprocess, sys, tempfile
from pathlib import Path

import numpy as np
import scipy.io.wavfile as wav

SR = 44100

# ime u aplikaciji: (fajl u paketu, od [s], trajanje [s] ili None = ceo, utišavanje [s], petlja)
IZBOR = {
    "karijera_uvod": ("corporate_office_background_music_loop/Corporate Loop.wav", 0, None, 0, True),
    "karijera_korporacija": ("quiz_game_background_music_loop/Jazz Swing Piano_4_(LOOP_1.19).wav", 0, None, 0, True),
    "karijera_firma": ("light_jazz_office_lounge_loop/soul jazz tunes bar 2063 - Eitan Epstein Music - 45 sec loop 1.wav", 0, None, 0, True),
    "karijera_posao": ("thinking_music_loop_light/Jazz Waltz loop.wav", 0, None, 0, True),
    "karijera_office": ("upbeat_corporate_motivational_loop/Corporate Upbeat Loop.wav", 0, None, 0, True),
    # „This Jazz 180” nije pravljen kao petlja: bez tišine na kraju, a spoj omekšan utišavanjem od 2 s.
    "karijera_probni_kraj": ("ticking_tension_quiz_loop/This Jazz 180 MIX VERSIONS/This Jazz 180 MIX Version 2.wav", 0, 66.0, 2.0, True),
    "karijera_duel": ("game_show_tension_loop/tension_54s_124bpm_byWormwoodMusic_LOOP.wav", 0, None, 0, True),
    # „Boss Battle” ima 1,56 s tišine na početku i 1,1 s na kraju: bez nje petlja nema rupu.
    "karijera_odbrana": ("boss_battle_quiz_music_short_loop/Boss Battle Video Game Loop.wav", 1.56, 67.7, 0, True),
    "karijera_unapredjenje": ("level_up_promotion_jingle/Game Win Logo 04.wav", 0, None, 0.3, False),
    # Fanfare su jedan komad od 30 s: vrh je od 4,2 do 9 s.
    "karijera_rekord": ("achievement_fanfare_short/fanfares.wav", 4.2, 4.8, 1.2, False),
    # „Success Corporate” traje 3 min: refren od 17 s.
    "karijera_uspeh": ("success_uplifting_corporate_short/Succes Corporate.wav", 17.0, 6.5, 1.8, False),
}


def kasa() -> np.ndarray:
    """„Ka-čing”: klik fioke pa dva udarca zvonceta (visoki tonovi koji brzo zamiru)."""
    t = np.arange(int(SR * 1.1)) / SR
    x = np.zeros_like(t)
    klik = (np.random.default_rng(3).standard_normal(int(SR * 0.025)) * np.exp(-np.linspace(0, 6, int(SR * 0.025))))
    x[: len(klik)] += 0.5 * klik
    for start, tonovi in [(0.06, (2637, 3951)), (0.17, (3136, 4699))]:
        tt = t - start
        m = tt >= 0
        for i, f in enumerate(tonovi):
            x[m] += (0.45 / (i + 1)) * np.sin(2 * np.pi * f * tt[m]) * np.exp(-tt[m] * 6.5)
    return x


def zvono() -> np.ndarray:
    """Zvono na vratima kancelarije: „ding-dong” (E5 pa C5) sa prizvucima, kao zvonce sa čekićem."""
    t = np.arange(int(SR * 2.2)) / SR
    x = np.zeros_like(t)
    for start, f in [(0.0, 659.25), (0.55, 523.25)]:
        tt = t - start
        m = tt >= 0
        for k, a in [(1, 1.0), (2.76, 0.35), (5.4, 0.12)]:
            x[m] += 0.35 * a * np.sin(2 * np.pi * f * k * tt[m]) * np.exp(-tt[m] * (2.2 + k * 0.6))
    return x


def glasnoca(putanja: Path) -> float:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(putanja), "-af", "loudnorm=print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True)
    j = r.stderr[r.stderr.rindex("{"):r.stderr.rindex("}") + 1]
    return float(json.loads(j)["input_i"])


def kodiraj(ulaz: Path, izlaz: Path, cilj: float, od: float = 0, trajanje=None, utisaj: float = 0, stereo=True):
    """Seče, utišava kraj i dodaje stalno pojačanje do cilja (LUFS), pa AAC u .m4a."""
    with tempfile.TemporaryDirectory() as d:
        isecak = Path(d) / "i.wav"
        filtri = []
        if utisaj and trajanje:
            filtri.append(f"afade=t=out:st={max(0, trajanje - utisaj):.3f}:d={utisaj:.3f}")
        elif utisaj:
            filtri.append(f"areverse,afade=t=in:d={utisaj:.3f},areverse")
        cmd = ["ffmpeg", "-v", "error", "-y", "-ss", str(od), "-i", str(ulaz)]
        if trajanje:
            cmd += ["-t", str(trajanje)]
        if filtri:
            cmd += ["-af", ",".join(filtri)]
        subprocess.run(cmd + ["-ar", str(SR), str(isecak)], check=True)
        pojacanje = cilj - glasnoca(isecak)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(isecak), "-af", f"volume={pojacanje:.2f}dB,alimiter=limit=0.89:level=false",
                        "-ac", "2" if stereo else "1", "-c:a", "aac", "-b:a", "96k" if stereo else "64k", str(izlaz)], check=True)


def main():
    izvor, cilj = Path(sys.argv[1]), Path(sys.argv[2])
    cilj.mkdir(parents=True, exist_ok=True)
    for ime, (fajl, od, trajanje, utisaj, petlja) in IZBOR.items():
        kodiraj(izvor / fajl, cilj / f"{ime}.m4a", -20.0 if petlja else -16.0, od, trajanje, utisaj)
        print("napravljeno", ime)
    with tempfile.TemporaryDirectory() as d:
        for ime, x in [("karijera_kasa", kasa()), ("karijera_zvono", zvono())]:
            p = Path(d) / f"{ime}.wav"
            wav.write(p, SR, (x / np.abs(x).max() * 0.8).astype(np.float32))
            kodiraj(p, cilj / f"{ime}.m4a", -16.0, stereo=False)
            print("sintetizovano", ime)


if __name__ == "__main__":
    main()
