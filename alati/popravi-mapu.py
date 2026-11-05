"""Popravke gotove mape src/lib/osvajanje/svet.json (vlasnik 03.11.2026), iste kao u alati/napravi-mapu.mjs:

1. Francuska Gvajana se briše iz Francuske: na mapi je bila roze parče u Južnoj Americi koje pripada
   Francuskoj (Evropa), pa se u partiji na Južnoj Americi nije moglo napasti.
2. Trinidad i Tobago dobija morski put do Portorika: u partiji na Severnoj Americi nije imao nijednog suseda.
3. Severni putevi (vlasnik 03.11 veče, „Kanada, Island, Amerika sa Azijom nisu lepo povezani”): kraj puta ide na
   obalu koja se vidi, ne na najbliži par tačaka (Svalbard, Aleuti kod Havaja, krajnji sever Grenlanda);
   novi put Island–Velika Britanija (preko Farskih ostrva).

Posle izmene proverava da je svaki kontinent povezan i da nijedna država nema deo daleko od svog kontinenta.
Upotreba: python3 alati/popravi-mapu.py src/lib/osvajanje/svet.json
"""
import json
import re
import sys
from collections import defaultdict

KONTINENTI = {"sam": ["sam", "kar"], "jam": ["jam"], "evr": ["sev", "zev", "jev", "iev"],
              "afr": ["saf", "zaf", "caf", "iaf", "jaf"], "azi": ["bli", "caz", "iaz", "jia"], "oke": ["oke"]}
NOVI_MORSKI = [("TTO", "PRI"), ("ISL", "GBR")]
# Ručno izabrani krajevi (x, y na karti 2000×921): Island–Norveška ide na kopno, ne na Svalbard; Aljaska ne Havaji.
KRAJEVI = {("ISL", "NOR"): (859.8, 104.4, 943.2, 127.1), ("RUS", "USA"): (1782.6, 100.7, 72.0, 182.3),
           ("CAN", "GRL"): (646.0, 97.8, 679.4, 100.6), ("ISL", "GBR"): (834.5, 116.9, 916.1, 132.5)}
# Prekomorski deo države: x središta dela manji od ove granice (Francuska Gvajana je na x≈600, Francuska na x≈1000).
PREKOMORSKO = {"FRA": lambda cx, cy: cx < 900}


def delovi(d):
    """Podputanje (M…Z) sa središtem."""
    for deo in re.findall(r"M[^M]*", d):
        n = list(map(float, re.findall(r"-?\d+\.?\d*", deo)))
        xs, ys = n[0::2], n[1::2]
        yield deo, (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2


def tacke(d):
    n = list(map(float, re.findall(r"-?\d+\.?\d*", d)))
    return list(zip(n[0::2], n[1::2]))


def proveri(svet):
    drz = {o["id"]: o for o in svet["drzave"]}
    sus = defaultdict(set)
    for a, b in svet["veze"]:
        sus[a].add(b)
        sus[b].add(a)
    for k, regioni in KONTINENTI.items():
        ids = {i for i, o in drz.items() if o["region"] in regioni}
        vid, red = set(), [next(iter(ids))]
        while red:
            x = red.pop()
            if x not in vid:
                vid.add(x)
                red += [n for n in sus[x] if n in ids]
        assert vid == ids, f"{k}: nepovezane {sorted(ids - vid)}"


def main(putanja):
    svet = json.load(open(putanja, encoding="utf-8"))
    for o in svet["drzave"]:
        if o["id"] in PREKOMORSKO:
            o["d"] = "".join(deo for deo, cx, cy in delovi(o["d"]) if not PREKOMORSKO[o["id"]](cx, cy))
    drz = {o["id"]: o for o in svet["drzave"]}
    postoji = {tuple(sorted(v)) for v in svet["veze"]}
    for a, b in NOVI_MORSKI:
        if tuple(sorted((a, b))) in postoji:
            continue
        # Krajevi puta: najbliži par tačaka obala (isto kao u napravi-mapu.mjs).
        p, q = min(((p, q) for p in tacke(drz[a]["d"]) for q in tacke(drz[b]["d"])),
                   key=lambda t: (t[0][0] - t[1][0]) ** 2 + (t[0][1] - t[1][1]) ** 2)
        svet["veze"].append([a, b])
        svet["more"].append([a, b, round(p[0], 1), round(p[1], 1), round(q[0], 1), round(q[1], 1)])
    for m in svet["more"]:
        if tuple(m[:2]) in KRAJEVI:
            m[2:6] = KRAJEVI[tuple(m[:2])]
    proveri(svet)
    json.dump(svet, open(putanja, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print("ok:", len(svet["drzave"]), "država,", len(svet["veze"]), "veza,", len(svet["more"]), "morskih")


if __name__ == "__main__":
    main(sys.argv[1])
