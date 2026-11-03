#!/usr/bin/env python3
"""
Obrada novih pitanja iz Excel-a (kviz-srpski.xlsx) pre uvoza u bazu.

Koraci: čišćenje teksta → provera (4 različita odgovora, dužine) → provera prevoda
(engleski ostaci, hrvatski oblici, ijekavica, ćirilica, pokvareni znaci) → duplikati
(u fajlu i prema postojećim pitanjima iz baze) → kategorija po ključnim rečima.

Ulaz:  putanja do .xlsx i (opciono) JSON postojećih pitanja [{"t": tekst}].
Izlaz: folder sa uvoz.jsonl (za bazu), pregled.csv (za urednika) i izvestaj.json.

Primer:
  python3 alati/uvoz-pitanja.py ~/Downloads/kviz-srpski.xlsx postojeca.json izlaz/
"""
import csv, json, re, sys, unicodedata
from collections import Counter
from pathlib import Path

import openpyxl

# Kategorije (tags) i ključne reči; prva koja se poklopi pobeđuje, pa su uže kategorije gore.
KATEGORIJE = [
    ("sport", r"fudbal|košark|tenis|olimpij|svetsk\w* prvenstv|reprezentac|klub|golman|stadion|šampion|odbojk|rukomet|vaterpolo|atletičar|bokser|formul\w* 1|trkač|skijaš|plivač|NBA|FIFA|UEFA|liga|turnir|medalj|maraton|šahist|šah\b|šahovsk|rvač|ringovsk|ining|bejzbol|NFL|NHL|hokej|golf|biciklist|Super ?Boul|WWE|SummerSlam|Rvanj"),
    ("muzika", r"pesm|pevač|bend|grup[ae] .*album|album|kompozitor|opera|simfonij|muzič|muzik|gitar|klavir|violin|hit\b|rok |rep |džez|orkestar|singl|Evrovizij|pesam|pesmom|grup[ae] .{0,30}(The|pesm|hit)|muzičar"),
    ("film i tv", r"film|serij|glumi|glumac|glumic|režis|reditelj|Oskar|crtan|TV |televizij|Holivud|sitkom|lik iz|ulog"),
    ("književnost", r"roman|pisac|pisc|pesnik|pesnic|pesm[ae] .*napisa|napisao|napisala|književ|knjig|delo .*autor|autor[a ]|pripovet|drama|dramsk|Šekspir|Andrić|Njegoš|junak|junakinj|poem|bajk|basn|epsk|Hari Poter|Tolkin|Gospodar prstenova"),
    ("umetnost", r"slikar|slik[ae]|vajar|skulptur|umetni|galerij|muzej|arhitekt|katedral|freska|impresion|renesans|barok"),
    ("geografija", r"glavni grad|prestonic|reka|reke|planin|ostrv|država|države|kontinent|okean|more\b|mora\b|jezer|pustinj|grad[a ]|zastav|granič|stanovnik|vrh\b|poluostrv|moreuz|zalив|zaliv|vulkan"),
    ("istorija", r"godine \d|veku|veka\b|rat\b|rata\b|ratu|bitk|car\b|cara\b|kralj|kraljic|imperij|carstv|dinastij|revolucij|predsednik|vladar|osvoj|antičk|srednj\w* vek|Nemanjić|Tito|Hitler|Napoleon"),
    ("nauka", r"hemij|hemijsk|element|atom|molekul|fizik|fizičar|biolog|ćelij|gen[ae]?\b|DNK|planet|zvezd|galaksij|astronom|matemati|broj\w* |jednačin|formul|naučnik|izum|izumi|teorij|kiseonik|vodonik|simbol\b"),
    ("priroda", r"životinj|ptic|riba|riba\b|sisar|insekt|biljk|drvo|cveć|cvet|pas\b|mačk|lav\b|zmij|gmizav|vrst[ae]"),
    ("jezik", r"reč\b|reči\b|izraz|znači|značenje|sinonim|antonim|jezik|jezič|slovo|slova|izgovor|pravopis|latinsk\w* reč|poreklo reči|izreka|poslovic|galicizam|anglicizam|turcizam"),
    ("religija i mitologija", r"religij|bog\b|boga|boginj|mitolog|Zevs|Biblij|apostol|svet[ia] |crkv|islam|budiz|hram\b|patrijarh|svetac|Isus|prorok"),
    ("hrana i piće", r"jelo|hran|kuhinj|vino|pivo|piće|sir\b|voće|povrć|začin|kolač|torta|recept|koktel|kafa|čaj\b"),
    ("tehnika", r"računar|kompjuter|internet|softver|telefon|aplikacij|automobil|marka automobila|motor\b|avion|raket|robot|programsk"),
]
# Jezik pre geografije i istorije („izreka” nije reka); svaka reč mora da počne na granici reči.
KATEGORIJE.insert(3, KATEGORIJE.pop(next(i for i, (k, _) in enumerate(KATEGORIJE) if k == "jezik")))
KATEGORIJE = [(k, re.compile(r"\b(?:" + r + ")", re.IGNORECASE)) for k, r in KATEGORIJE]

ENGLESKI = re.compile(r"\b(the|which|what|who|where|when|how|of the|is the|was the|and the|in the)\b", re.IGNORECASE)
# Hrvatski oblici i ijekavica koji ne smeju u ekavsku bazu (Gram/kviz su ekavski).
HRVATSKI = re.compile(
    r"\b(tko|tisuć\w*|kazališt\w*|sveučilišt\w*|glazb\w*|znanost\w*|tjed\w*|kruh\w*|općin\w*|opć\w*|zrakoplov\w*|nogomet\w*|"
    r"rijek\w*|vrijem\w*|mjest\w*|mjesec\w*|bijel\w*|lijep\w*|dijete|djeca|djec\w*|svijet\w*|cvijet\w*|vjer\w*|mlijek\w*|"
    r"stoljeć\w*|ožujk\w*|siječanj\w*|veljač\w*|travanj\w*|lipanj\w*|srpanj\w*|kolovoz\w*|rujan\w*|listopad\w*|studeni\w*|prosinac\w*|"
    r"hrvatsk\w* sabor|kemij\w*|kemičar\w*|tvornic\w*|zemljopis\w*|povijest\w*|izumio je|otok\w*)\b",
    re.IGNORECASE,
)
CIRILICA = re.compile(r"[Ѐ-ӿ]")
POKVARENO = re.compile(r"Ã|Ä|Å|&quot;|&amp;|&#\d+;|�|\?\?")
NAVODI = re.compile(r"„[^”“]*[”“]|\"[^\"]*\"|“[^”]*”")
CIR_LAT = dict(zip(
    "абвгдђежзијклљмнњопрстћуфхцчџшАБВГДЂЕЖЗИЈКЛЉМНЊОПРСТЋУФХЦЧЏШ",
    ["a", "b", "v", "g", "d", "đ", "e", "ž", "z", "i", "j", "k", "l", "lj", "m", "n", "nj", "o", "p", "r", "s", "t", "ć", "u", "f", "h", "c", "č", "dž", "š",
     "A", "B", "V", "G", "D", "Đ", "E", "Ž", "Z", "I", "J", "K", "L", "Lj", "M", "N", "Nj", "O", "P", "R", "S", "T", "Ć", "U", "F", "H", "C", "Č", "Dž", "Š"]))


def u_latinicu(t):
    """Srpska ćirilica → latinica (deo redova je stigao na ćirilici)."""
    return "".join(CIR_LAT.get(c, c) for c in t)


def ocisti(t):
    if t is None:
        return ""
    t = unicodedata.normalize("NFC", str(t)).strip()
    t = re.sub(r"\s+", " ", t)
    t = t.replace(" ?", "?").replace(" ,", ",").replace(" .", ".")
    return t


def veliko_prvo(t):
    return t[:1].upper() + t[1:] if t else t


def kljuc(t):
    """Ključ za duplikate: mala slova, bez dijakritika i interpunkcije, sažeti razmaci."""
    t = unicodedata.normalize("NFKD", t.lower())
    t = "".join(c for c in t if not unicodedata.combining(c)).replace("đ", "dj")
    t = re.sub(r"[^a-z0-9 ]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def kategorija(pitanje, tacan):
    tekst = f"{pitanje} {tacan}"
    for ime, rx in KATEGORIJE:
        if rx.search(tekst):
            return ime
    return "opšte"


def problemi_prevoda(polja):
    """Naslovi u navodnicima i vlastita imena (velikim slovom, ne na početku) se ne računaju: „Bijelo dugme” je ispravno."""
    tekst = " ".join(polja)
    p = []
    # Engleski ostatak se traži samo u pitanju van navodnika; odgovori smeju biti engleski naslovi i imena.
    if any(m.group(0).islower() for m in ENGLESKI.finditer(NAVODI.sub(" ", polja[0]))):
        p.append("engleski ostatak")
    bez = NAVODI.sub(" ", tekst)
    if any(m.group(0)[0].islower() or m.start() == 0 for m in HRVATSKI.finditer(bez)):
        p.append("hrvatski oblik ili ijekavica")
    if CIRILICA.search(tekst):
        p.append("ćirilica")
    if POKVARENO.search(tekst):
        p.append("pokvareni znaci")
    return p


def obradi(xlsx, postojeca, izlaz):
    wb = openpyxl.load_workbook(xlsx, read_only=True)
    redovi = list(wb.worksheets[0].iter_rows(values_only=True))[1:]
    vidjeno = {kljuc(t["t"]) for t in postojeca}
    u_fajlu = set()
    razlozi = Counter()
    po_izvoru = Counter()
    kategorije = Counter()
    uvoz, pregled = [], []
    for r in redovi:
        rid, izvor, pitanje, tacan, n1, n2, n3, napomena = (list(r) + [None] * 8)[:8]
        pitanje, tacan = veliko_prvo(u_latinicu(ocisti(pitanje))), veliko_prvo(u_latinicu(ocisti(tacan)))
        netacni = [veliko_prvo(u_latinicu(ocisti(x))) for x in (n1, n2, n3)]
        razlog = None
        if not pitanje or not tacan:
            razlog = "prazno"
        elif not all(netacni):
            razlog = "otvoreno pitanje (nema 3 netačna)"
        elif len({kljuc(x) for x in [tacan] + netacni}) < 4:
            razlog = "odgovori se ponavljaju"
        elif not (12 <= len(pitanje) <= 300) or max(len(x) for x in [tacan] + netacni) > 120:
            razlog = "dužina"
        elif napomena and ("pokvaren" in napomena or "skoro duplikat" in napomena):
            razlog = napomena
        k = kljuc(pitanje) + "|" + kljuc(tacan)
        if razlog is None and (kljuc(pitanje) in vidjeno or k in u_fajlu):
            razlog = "duplikat"
        prevod = problemi_prevoda([pitanje, tacan] + netacni) if razlog is None else []
        if razlog is None and prevod:
            razlog = "prevod: " + ", ".join(prevod)
        if razlog is None and napomena:
            # „proveriti” napomene idu uredniku, ne u igru.
            razlog = "napomena: " + napomena
        if razlog:
            razlozi[razlog.split(":")[0] if razlog.startswith(("prevod", "napomena")) else razlog] += 1
            if razlog not in ("duplikat", "prazno"):
                pregled.append([rid, izvor, razlog, pitanje, tacan] + netacni)
            continue
        u_fajlu.add(k)
        vidjeno.add(kljuc(pitanje))
        kat = kategorija(pitanje, tacan)
        kategorije[kat] += 1
        po_izvoru[izvor] += 1
        uvoz.append({"id": rid, "izvor": izvor, "pitanje": pitanje, "tacan": tacan, "netacni": netacni, "kategorija": kat,
                     "tezina": "hard" if izvor in ("HKS",) else "medium"})
    izlaz.mkdir(parents=True, exist_ok=True)
    with open(izlaz / "uvoz.jsonl", "w") as f:
        for u in uvoz:
            f.write(json.dumps(u, ensure_ascii=False) + "\n")
    with open(izlaz / "pregled.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "izvor", "razlog", "pitanje", "tacan", "netacan_1", "netacan_2", "netacan_3"])
        w.writerows(pregled)
    izvestaj = {"ulaz": len(redovi), "za_uvoz": len(uvoz), "odbaceno": dict(razlozi.most_common()),
                "po_izvoru": dict(po_izvoru.most_common()), "kategorije": dict(kategorije.most_common())}
    (izlaz / "izvestaj.json").write_text(json.dumps(izvestaj, ensure_ascii=False, indent=2))
    return izvestaj


def _provera():
    assert kljuc("Koja je  REKA?") == kljuc("koja je reka")
    assert kategorija("Koji fudbalski klub je osvojio ligu?", "Zvezda") == "sport"
    assert "hrvatski oblik ili ijekavica" in problemi_prevoda(["Tko je napisao roman?"])
    assert problemi_prevoda(["Ko je napisao roman „Na Drini ćuprija”?"]) == []
    assert problemi_prevoda(["Koja grupa peva „Lipe cvatu”?", "Bijelo dugme"]) == []
    assert "engleski ostatak" in problemi_prevoda(["Which country is the largest?"])
    assert kategorija("Koja latinska izreka znači „iskoristi dan”?", "Carpe diem") == "jezik"
    assert u_latinicu("Ђурђевдан") == "Đurđevdan"
    assert veliko_prvo("džef") == "Džef"


if __name__ == "__main__":
    _provera()
    postojeca = json.loads(Path(sys.argv[2]).read_text()) if len(sys.argv) > 2 and sys.argv[2] != "-" else []
    print(json.dumps(obradi(sys.argv[1], postojeca, Path(sys.argv[3] if len(sys.argv) > 3 else "izlaz")), ensure_ascii=False, indent=2))
