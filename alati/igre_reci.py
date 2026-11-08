#!/usr/bin/env python3
"""Igre reči: rečnik za proveru i dnevne zagonetke za šest igara.

Izvori: srLex 1.3 (librum-gram/data), pojmovnici iz Librum Grama, reči za Vešanje iz baze (alati/igre_reci_vesanje.json)
i teme za Zmiju (alati/igre_reci_teme.json). Sve je ekavica i latinica.

    python3 alati/igre_reci.py recnik            # src/lib/igre/reci.txt (provera unosa u app)
    python3 alati/igre_reci.py zagonetke 2026-11-09 180   # scripts/igre-reci/zagonetke.json
    python3 alati/igre_reci.py provera           # proverava rečnik i sve zagonetke (assert)

Zagonetka za isti dan je uvek ista (seme = igra + datum), pa se generator sme pustiti ponovo.
"""
from __future__ import annotations

import datetime as dt
import gzip
import json
import random
import re
import sys
from collections import Counter, defaultdict, deque
from pathlib import Path

KOREN = Path(__file__).resolve().parent.parent
GRAM = KOREN.parent / "Claude" / "librum-gram" / "data"
RECNIK = KOREN / "src" / "lib" / "igre" / "reci.txt"
ZAGONETKE = KOREN / "scripts" / "igre-reci" / "zagonetke.json"
VESANJE = KOREN / "alati" / "igre_reci_vesanje.json"
TEME = KOREN / "alati" / "igre_reci_teme.json"

AZBUKA = set("abcčćdđefghijklmnoprsštuvzž")
# Ijekavski oblici u srLex-u vode na ekavsku lemu (mlijeko → mleko); takvi oblici ne ulaze.
IJEKAVICA = re.compile(r"ije|vje|dje|pje|mje|bje|sje|tje|cje|zje|rje|nje(?=[dt])")
# Psovke, vulgarnosti i pogrdni nazivi: ne smeju biti rešenje ni predlog.
ZABRANJENO_POCETAK = ("jeb", "kurac", "kurc", "kurč", "pičk", "pick", "pizd", "sranj", "govn", "kurv", "peder", "drolj",
                      "šupk", "šupak", "prdež", "drkad", "cigan", "šiptar", "ustaš", "balij", "kretén", "debil", "idiot",
                      "kreten", "retard", "smrd", "fuk")
ZABRANJENO_TACNO = {"dupe", "guza", "guzica", "sisa", "sise", "muda", "kita", "kitu", "prdi", "seks", "drot", "pička"}

MIN_FREKV_PROVERA = 40     # oblik se prihvata kao unos ako se javlja bar toliko puta u korpusu
MIN_FREKV_RESENJE = 1500   # lema postaje rešenje tek kad je dovoljno poznata
NE_PODRECI = {"opel", "omer", "emo", "mob", "oka", "eda", "ana", "ema", "ola", "pop", "dom", "kom", "tom", "rom"} - {"dom", "pop", "kom"}


def je_cista(rec: str) -> bool:
    """Prava reč za igru: samo naša slova, bez ijekavice i bez zabranjenih reči. Primer: je_cista("mleko") → True."""
    if not rec or any(z not in AZBUKA for z in rec):
        return False
    if IJEKAVICA.search(rec):
        return False
    return rec not in ZABRANJENO_TACNO and not rec.startswith(ZABRANJENO_POCETAK)


def ucitaj_srlex():
    """Vraća (oblici za proveru, česte leme po vrsti). Leme: {"imenica": {rec: frekv}, "ostalo": {...}}."""
    oblici: Counter = Counter()
    leme = {"imenica": Counter(), "ostalo": Counter()}
    with gzip.open(GRAM / "srLex_v1.3.gz", "rt", encoding="utf-8") as f:
        for red in f:
            d = red.rstrip("\n").split("\t")
            if len(d) < 8:
                continue
            oblik, lema, msd = d[0], d[1], d[2]
            frekv = int(d[6]) if d[6].isdigit() else 0
            if not (3 <= len(oblik) <= 9) or oblik != oblik.lower() or not je_cista(oblik):
                continue
            if msd.startswith("Np") or msd.startswith("Y"):
                continue   # vlastita imena i skraćenice
            oblici[oblik] += frekv
            if oblik != lema:
                continue
            if msd.startswith("Nc") and msd[3:5] == "sn":
                leme["imenica"][lema] += frekv
            elif msd.startswith(("Agpmsn", "Vmn", "Rg")):
                leme["ostalo"][lema] += frekv
    provera = {o for o, n in oblici.items() if n >= MIN_FREKV_PROVERA}
    return provera, leme


# ---------- igre ----------

def premetaljka(rng: random.Random, imenice: list[str], leme: set[str]) -> dict:
    """7 slova; glavna reč koristi sva, ostale (≥3 slova) svako slovo najviše onoliko puta koliko ga ima."""
    kandidati = [r for r in imenice if len(r) == 7]
    while True:
        glavna = rng.choice(kandidati)
        zbir = Counter(glavna)
        reci = sorted(r for r in leme if 3 <= len(r) <= 7 and not (Counter(r) - zbir))
        if 15 <= len(reci) <= 70:
            slova = list(glavna)
            while "".join(slova) == glavna:
                rng.shuffle(slova)
            return {"slova": slova, "glavna": glavna, "reci": reci}


def pet_slova(rng: random.Random, imenice: list[str]) -> dict:
    """Reč od 5 slova, 6 pokušaja."""
    return {"rec": rng.choice([r for r in imenice if len(r) == 5])}


def jedno_slovo_razlike(a: str, b: str) -> bool:
    """Primer: jedno_slovo_razlike("kosa", "kasa") → True."""
    return len(a) == len(b) and sum(x != y for x, y in zip(a, b)) == 1


def lanac(rng: random.Random, imenice: list[str], leme: set[str]) -> dict:
    """Od reči do reči menjajući po jedno slovo. Primer puta ide samo kroz poznate osnovne reči (ne „menu”, „zenu”);
    igrač sme i kroz druge oblike iz rečnika. Najkraći put 4–6 koraka."""
    duzina = 4
    skup = [r for r in leme if len(r) == duzina]
    po_obrascu = defaultdict(list)
    for r in skup:
        for i in range(duzina):
            po_obrascu[r[:i] + "_" + r[i + 1:]].append(r)
    pocetne = [r for r in imenice if len(r) == duzina and r in leme]
    while True:
        start = rng.choice(pocetne)
        pret = {start: None}
        red = deque([start])
        while red:
            r = red.popleft()
            for i in range(duzina):
                for s in po_obrascu[r[:i] + "_" + r[i + 1:]]:
                    if s not in pret:
                        pret[s] = r
                        red.append(s)
        ciljevi = [r for r in pocetne if r in pret and 4 <= put_duzina(pret, r) <= 6]
        if not ciljevi:
            continue
        cilj = rng.choice(ciljevi)
        put = [cilj]
        while pret[put[-1]] is not None:
            put.append(pret[put[-1]])
        return {"od": start, "do": cilj, "primer": put[::-1], "najmanje": len(put) - 1}


def put_duzina(pret: dict, r: str) -> int:
    n = 0
    while pret[r] is not None:
        r, n = pret[r], n + 1
    return n


def ukrsti(rng: random.Random, reci: list[str], sirina: int, visina: int, cilj: int, pokusaja: int = 400) -> list[dict] | None:
    """Slobodna ukrštenica: reči se ukrštaju, ne dodiruju se bočno. Vraća [{rec, x, y, smer}] ili None."""
    mreza: dict[tuple[int, int], str] = {}
    postavljene: list[dict] = []

    def moze(rec: str, x: int, y: int, smer: str) -> int:
        dx, dy = (1, 0) if smer == "v" else (0, 1)
        kx, ky = x + dx * (len(rec) - 1), y + dy * (len(rec) - 1)
        if x < 0 or y < 0 or kx >= sirina or ky >= visina:
            return -1
        if mreza.get((x - dx, y - dy)) or mreza.get((kx + dx, ky + dy)):
            return -1
        ukrstanja = 0
        for i, z in enumerate(rec):
            p = (x + dx * i, y + dy * i)
            if p in mreza:
                if mreza[p] != z:
                    return -1
                ukrstanja += 1
                continue
            # prazno polje: susedi popreko moraju biti prazni
            if mreza.get((p[0] + dy, p[1] + dx)) or mreza.get((p[0] - dy, p[1] - dx)):
                return -1
        return ukrstanja

    def stavi(rec, x, y, smer):
        dx, dy = (1, 0) if smer == "v" else (0, 1)
        for i, z in enumerate(rec):
            mreza[(x + dx * i, y + dy * i)] = z
        postavljene.append({"rec": rec, "x": x, "y": y, "smer": smer})

    prva = rng.choice([r for r in reci if len(r) >= min(sirina, 6)] or reci)
    if len(prva) > sirina:
        return None
    stavi(prva, (sirina - len(prva)) // 2, visina // 2, "v")
    koriscene = {prva}
    for _ in range(pokusaja):
        if len(postavljene) >= cilj:
            break
        rec = rng.choice(reci)
        if rec in koriscene:
            continue
        mesta = []
        for (px, py), z in list(mreza.items()):
            for i, zr in enumerate(rec):
                if zr != z:
                    continue
                for smer in ("v", "u"):
                    x, y = (px - i, py) if smer == "v" else (px, py - i)
                    u = moze(rec, x, y, smer)
                    if u > 0:
                        mesta.append((u, x, y, smer))
        if mesta:
            mesta.sort(key=lambda m: -m[0])
            _, x, y, smer = rng.choice(mesta[:3])
            stavi(rec, x, y, smer)
            koriscene.add(rec)
    return postavljene if len(postavljene) >= cilj else None


def mreza_iz(postavljene: list[dict]) -> dict[tuple[int, int], str]:
    m = {}
    for p in postavljene:
        dx, dy = (1, 0) if p["smer"] == "v" else (0, 1)
        for i, z in enumerate(p["rec"]):
            m[(p["x"] + dx * i, p["y"] + dy * i)] = z
    return m


def sifra(rng: random.Random, imenice: list[str]) -> dict:
    """Ukrštenica bez opisa: svako slovo je broj; tri slova su data na početku."""
    pul = [r for r in imenice if 4 <= len(r) <= 8]
    while True:
        p = ukrsti(rng, pul, 9, 9, 10)
        if not p:
            continue
        m = mreza_iz(p)
        slova = sorted(set(m.values()))
        if len(slova) < 14:
            continue
        brojevi = list(range(1, len(slova) + 1))
        rng.shuffle(brojevi)
        kod = dict(zip(slova, brojevi))
        ucestala = [z for z, _ in Counter(m.values()).most_common()]
        data = rng.sample(ucestala[:8], 3)
        return {
            "sirina": 9, "visina": 9,
            "polja": [[x, y, kod[z]] for (x, y), z in sorted(m.items())],
            "kljuc": {str(n): z for z, n in kod.items()},
            "data": sorted(kod[z] for z in data),
            "reci": [x["rec"] for x in p],
        }


def ukrstenica(rng: random.Random, opisi: dict[str, str], moderne: set[str]) -> dict:
    """Mala ukrštenica sa opisima (Vešanje + pojmovnici); moderne reči 6× češće od arhaizama."""
    pul = [r for r in sorted(opisi) if 3 <= len(r) <= 9 for _ in range(6 if r in moderne else 1)]
    while True:
        p = ukrsti(rng, pul, 9, 9, 7, 800)
        if not p:
            continue
        # brojevi kao u štampanoj ukrštenici: redom po početnom polju
        pocetci = sorted({(x["y"], x["x"]) for x in p})
        broj = {(x, y): i + 1 for i, (y, x) in enumerate(pocetci)}
        return {
            "sirina": 9, "visina": 9,
            "reci": [{**x, "broj": broj[(x["x"], x["y"])], "opis": opisi[x["rec"]]} for x in p],
        }


def zmija(rng: random.Random, teme: dict[str, list[str]], sirina: int = 6, visina: int = 6) -> dict:
    """Tema dana: reči teme popunjavaju celu mrežu, svaka kao neprekinut put kroz susedna polja (gore/dole/levo/desno)."""
    ukupno = sirina * visina
    while True:
        tema = rng.choice(sorted(teme))
        reci = [r for r in teme[tema] if 4 <= len(r) <= 9]
        rng.shuffle(reci)
        izbor = izaberi_zbir(reci, ukupno)
        if not izbor:
            continue
        put = hamiltonov_put(rng, sirina, visina)
        slova = [[""] * sirina for _ in range(visina)]
        polozaji = []
        i = 0
        for r in izbor:
            deo = put[i:i + len(r)]
            for (x, y), z in zip(deo, r):
                slova[y][x] = z
            polozaji.append({"rec": r, "put": [[x, y] for x, y in deo]})
            i += len(r)
        return {"tema": tema, "sirina": sirina, "visina": visina, "slova": ["".join(red) for red in slova], "reci": polozaji}


def izaberi_zbir(reci: list[str], cilj: int) -> list[str] | None:
    """Prvi podskup reči čije dužine daju tačno cilj (5–8 reči), pretraga u dubinu."""
    def trazi(i, ostalo, izabrane):
        if ostalo == 0:
            return izabrane if 5 <= len(izabrane) <= 8 else None
        if i >= len(reci) or ostalo < 0 or len(izabrane) >= 8:
            return None
        return trazi(i + 1, ostalo - len(reci[i]), izabrane + [reci[i]]) or trazi(i + 1, ostalo, izabrane)
    return trazi(0, cilj, [])


def hamiltonov_put(rng: random.Random, sirina: int, visina: int) -> list[tuple[int, int]]:
    """Nasumičan put kroz sva polja: zmija red po red pa „backbite” preokretanja (ostaje ispravan put)."""
    put = [(x if y % 2 == 0 else sirina - 1 - x, y) for y in range(visina) for x in range(sirina)]
    for _ in range(sirina * visina * 30):
        if rng.random() < 0.5:
            put.reverse()
        kraj = put[-1]
        susedi = [(kraj[0] + dx, kraj[1] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        susedi = [s for s in susedi if 0 <= s[0] < sirina and 0 <= s[1] < visina and s != put[-2]]
        s = rng.choice(susedi)
        i = put.index(s)
        put = put[:i + 1] + put[i + 1:][::-1]
    return put


# ---------- opisi za ukrštenicu ----------

CIR = dict(zip("абвгдђежзијклљмнњопрстћуфхцчџш", ["a", "b", "v", "g", "d", "đ", "e", "ž", "z", "i", "j", "k", "l", "lj", "m", "n",
                                                  "nj", "o", "p", "r", "s", "t", "ć", "u", "f", "h", "c", "č", "dž", "š"]))


def u_latinicu(t: str) -> str:
    return "".join(CIR.get(z, CIR.get(z.lower(), z).capitalize() if z.lower() in CIR else z) for z in t)


def ucitaj_opise(provera: set[str]) -> tuple[dict[str, str], set[str]]:
    """(reč → kratak opis, moderne reči). Opis ne sme da sadrži samu reč ni njen koren; arhaizmi nisu moderni."""
    opisi: dict[str, str] = {}
    arhaizmi: set[str] = set()
    if VESANJE.exists():
        for r in json.loads(VESANJE.read_text()):
            opisi[r["word"].lower()] = r["hint"].strip()
    for ime in ("pojmovnik-arhaizmi.txt", "pojmovnik-manje-poznate.txt"):
        for red in (GRAM / ime).read_text(encoding="utf-8").splitlines():
            if " – " not in red:
                continue
            rec, opis = red.split(" – ", 1)
            rec, opis = u_latinicu(rec.strip()).lower(), u_latinicu(opis.split(";")[0].strip())
            opisi.setdefault(rec, opis[:1].upper() + opis[1:])
            arhaizmi.add(rec)
    for red in (GRAM / "pojmovnik-recnikopedija.txt").read_text(encoding="utf-8").splitlines():
        m = re.match(r"(\S+) – .*?\b(označava|opisuje|znači)\s+(.+)", red)
        if m:
            opis = re.split(r"[.;:(]|, (?:odnosno|ili|a|ali|kao)\b", m.group(3))[0].strip()
            opisi.setdefault(m.group(1).lower(), opis[:1].upper() + opis[1:])
    cisti = {}
    for rec, opis in opisi.items():
        opis = re.sub(r"\s+", " ", opis).strip(" ,")
        if not je_cista(rec) or not (3 <= len(rec) <= 9) or not (6 <= len(opis) <= 70):
            continue
        if rec[:4] in opis.lower() or IJEKAVICA.search(opis.lower()):
            continue
        cisti[rec] = opis
    return cisti, {r for r in cisti if r not in arhaizmi}


# ---------- glavno ----------

IGRE = ("premetaljka", "pet_slova", "lanac", "sifra", "ukrstenica", "zmija")


def napravi_recnik():
    provera, leme = ucitaj_srlex()
    RECNIK.write_text("\n".join(sorted(provera)) + "\n", encoding="utf-8")
    print(f"{RECNIK.relative_to(KOREN)}: {len(provera)} reči")


def napravi_zagonetke(od: dt.date, dana: int):
    provera, leme = ucitaj_srlex()
    imenice = sorted(r for r, n in leme["imenica"].items() if n >= MIN_FREKV_RESENJE and r in provera)
    # podreči Premetaljke: dovoljno poznate leme, bez imena brendova i skraćenica u malim slovima
    sve_leme = {r for v in leme.values() for r, n in v.items() if n >= MIN_FREKV_RESENJE and r in provera} - NE_PODRECI
    opisi, moderne = ucitaj_opise(provera)
    teme = json.loads(TEME.read_text(encoding="utf-8"))
    print(f"imenica {len(imenice)}, lema {len(sve_leme)}, opisa {len(opisi)}, tema {len(teme)}")
    izlaz = {}
    poslednje: dict[str, deque] = {i: deque(maxlen=30) for i in IGRE}   # isto rešenje ne ponavlja se 30 dana
    for d in range(dana):
        datum = (od + dt.timedelta(days=d)).isoformat()
        dan = {}
        for igra in IGRE:
            rng = random.Random(f"{igra}:{datum}")
            for _ in range(50):
                if igra == "premetaljka":
                    z = premetaljka(rng, imenice, sve_leme); kljuc = z["glavna"]
                elif igra == "pet_slova":
                    z = pet_slova(rng, imenice); kljuc = z["rec"]
                elif igra == "lanac":
                    z = lanac(rng, imenice, sve_leme); kljuc = z["od"] + z["do"]
                elif igra == "sifra":
                    z = sifra(rng, imenice); kljuc = z["reci"][0]
                elif igra == "ukrstenica":
                    z = ukrstenica(rng, opisi, moderne); kljuc = z["reci"][0]["rec"]
                else:
                    z = zmija(rng, teme); kljuc = z["tema"]
                if kljuc not in poslednje[igra]:
                    break
            poslednje[igra].append(kljuc)
            dan[igra] = z
        izlaz[datum] = dan
        print(datum, end="\r")
    ZAGONETKE.parent.mkdir(parents=True, exist_ok=True)
    ZAGONETKE.write_text(json.dumps(izlaz, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"\n{ZAGONETKE.relative_to(KOREN)}: {len(izlaz)} dana")


def proveri():
    provera = set(RECNIK.read_text(encoding="utf-8").split())
    assert len(provera) > 20000 and "kuća" in provera and "mleko" in provera and "mlijeko" not in provera
    assert not any(r.startswith(ZABRANJENO_POCETAK) or r in ZABRANJENO_TACNO for r in provera)
    assert jedno_slovo_razlike("kosa", "kasa") and not jedno_slovo_razlike("kosa", "kosa")
    sve = json.loads(ZAGONETKE.read_text(encoding="utf-8"))
    for datum, dan in sve.items():
        p = dan["premetaljka"]
        assert sorted(p["slova"]) == sorted(p["glavna"]) and p["glavna"] in p["reci"], datum
        assert all(not (Counter(r) - Counter(p["glavna"])) for r in p["reci"]), datum
        assert dan["pet_slova"]["rec"] in provera and len(dan["pet_slova"]["rec"]) == 5, datum
        l = dan["lanac"]
        assert l["primer"][0] == l["od"] and l["primer"][-1] == l["do"] and len(l["primer"]) - 1 == l["najmanje"], datum
        assert all(jedno_slovo_razlike(a, b) and b in provera for a, b in zip(l["primer"], l["primer"][1:])), datum
        s = dan["sifra"]
        assert len(set(s["kljuc"].values())) == len(s["kljuc"]) and all(str(n) in s["kljuc"] for n in s["data"]), datum
        for igra in ("sifra", "ukrstenica"):
            reci = dan[igra]["reci"]
            postavljene = [r if isinstance(r, dict) else None for r in reci]
            if igra == "ukrstenica":
                m = mreza_iz(postavljene)
                assert all(0 <= x < 9 and 0 <= y < 9 for x, y in m), datum
                assert len({r["broj"] for r in reci}) <= len(reci) and all(r["opis"] for r in reci), datum
        z = dan["zmija"]
        polja = [tuple(c) for r in z["reci"] for c in r["put"]]
        assert len(polja) == len(set(polja)) == z["sirina"] * z["visina"], datum
        for r in z["reci"]:
            assert "".join(z["slova"][y][x] for x, y in r["put"]) == r["rec"], datum
            assert all(abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1 for a, b in zip(r["put"], r["put"][1:])), datum
    print(f"provera OK: rečnik {len(provera)}, {len(sve)} dana × {len(IGRE)} igara")


if __name__ == "__main__":
    komanda = sys.argv[1] if len(sys.argv) > 1 else "provera"
    if komanda == "recnik":
        napravi_recnik()
    elif komanda == "zagonetke":
        napravi_zagonetke(dt.date.fromisoformat(sys.argv[2]), int(sys.argv[3]))
    else:
        proveri()
