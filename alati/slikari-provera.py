"""Slikari: izbaci dela bez slike i zameni Wikimedia „Special:FilePath” direktnom adresom sličice.

Vlasnik 03.11.2026: pitanje bez slike ne sme u Slikare, a slika mora da se pojavi odmah.
FilePath ide kroz preusmerenje i pravljenje sličice na zahtev (sekunde, a pod opterećenjem
429); direktna thumb adresa je iz keša. Adrese se traže preko Commons API-ja, 50 po zahtevu
(pojedinačni zahtevi brzo dobiju 429). Delo čija datoteka ne postoji ispada.

Upotreba (posle alati/slikari-u-json.py):
  python3 -I alati/slikari-provera.py src/lib/igre/slikari.json
"""
import json
import sys
import time
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
ZAGLAVLJA = {"User-Agent": "LibrumKviz/1.0 (info@librum.club)"}
SIRINA = 960  # standardna Wikimedia širina: već napravljena i keširana
PO_ZAHTEVU = 50  # najviše naslova po API zahtevu
PAUZA_S = 1.0


def naslov_datoteke(slika):
    """Naslov „File:…” iz FilePath adrese.

    >>> naslov_datoteke("https://commons.wikimedia.org/wiki/Special:FilePath/Mona%20Lisa.jpg?width=800")
    'File:Mona Lisa.jpg'
    """
    putanja = urllib.parse.urlsplit(slika).path
    return "File:" + urllib.parse.unquote(putanja.split("Special:FilePath/", 1)[1])


def slicice(naslovi):
    """Za listu naslova vrati {naslov: thumb adresa}; nepostojeće datoteke izostaju."""
    telo = urllib.parse.urlencode({"action": "query", "format": "json", "prop": "imageinfo", "iiprop": "url|mime",
                                   "iiurlwidth": SIRINA, "redirects": 1, "titles": "|".join(naslovi)}).encode()
    for pokusaj in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(API, data=telo, headers=ZAGLAVLJA), timeout=60) as o:
                odgovor = json.load(o)["query"]
            break
        except urllib.error.HTTPError as greska:
            if greska.code != 429:
                raise
            time.sleep(10 * (pokusaj + 1))  # 429 znači „sačekaj”, ne „slika ne postoji”
    else:
        raise RuntimeError("Commons API stalno vraća 429")
    # Ulazni naslov → konačni naslov (normalizacija pa preusmerenje).
    konacni = {n: n for n in naslovi}
    for vrsta in ("normalized", "redirects"):
        prevod = {p["from"]: p["to"] for p in odgovor.get(vrsta, [])}
        konacni = {n: prevod.get(k, k) for n, k in konacni.items()}
    adrese = {}
    for strana in odgovor["pages"].values():
        info = (strana.get("imageinfo") or [{}])[0]
        if "missing" not in strana and info.get("mime", "").startswith("image/") and info.get("thumburl"):
            adrese[strana["title"]] = info["thumburl"].split("?")[0]  # utm_* razbija keš
    return {n: adrese[k] for n, k in konacni.items() if k in adrese}


def main(putanja):
    dela = json.load(open(putanja, encoding="utf-8"))
    naslovi = sorted({naslov_datoteke(d["slika"]) for d in dela if "Special:FilePath/" in d["slika"]})
    adrese = {}
    for i in range(0, len(naslovi), PO_ZAHTEVU):
        adrese.update(slicice(naslovi[i:i + PO_ZAHTEVU]))
        time.sleep(PAUZA_S)
    ostaju, nema = [], []
    for delo in dela:
        if not delo["slika"]:
            continue
        if "Special:FilePath/" not in delo["slika"]:
            ostaju.append(delo)
        elif (adresa := adrese.get(naslov_datoteke(delo["slika"]))):
            ostaju.append({**delo, "slika": adresa})
        else:
            nema.append(delo["naziv"])
    assert ostaju and all("FilePath" not in d["slika"] for d in ostaju)
    json.dump(ostaju, open(putanja, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"bilo {len(dela)}, bez slike {sum(1 for d in dela if not d['slika'])}, datoteka ne postoji {len(nema)}, ostalo {len(ostaju)}")
    for n in nema:
        print("  nema datoteke:", n)


if __name__ == "__main__":
    main(sys.argv[1])
