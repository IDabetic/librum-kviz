#!/usr/bin/env python3
"""
Pitanja struka za Karijeru iz Excel fajla (vlasnik 05.11.2026, „novo kviz-pozicije.xlsx”) → JSON za tabelu karijera_pitanja.
Pitanja idu SAMO u Karijeru (tabela karijera_pitanja + pogled karijera_fond), ne u opšti fond drugih igara.

Fajl: jedan list po struci („01-marketing” … „20-moda”), kolone: tema, tezina, pitanje, tacan, netacan_1..3.
Odgovori se mešaju (seme = tekst pitanja, isto mešanje pri ponovnom pokretanju), teme na engleskom se prevode.

Upotreba: python3 -I alati/karijera_pitanja_iz_xlsx.py <fajl.xlsx> <izlaz.json>
Upis: 05.11 kroz privremenu funkciju sa jednokratnom tajnom (migracije karijera_27/28), funkcija je obrisana posle uvoza.
"""
import json, random, sys
import openpyxl

STRUKA = {"muzika": "muzicki", "film": "filmski", "sport": "sportski"}
TEZINA = {"lako": "easy", "srednje": "medium", "tesko": "hard"}
TEMA = {"history": "istorija", "music": "muzika", "film_and_tv": "film i tv", "film": "film i tv", "geography": "geografija",
        "science": "nauka", "arts_and_literature": "umetnost i književnost", "food_and_drink": "hrana i piće",
        "society_and_culture": "društvo i kultura", "sport_and_leisure": "sport", "umetnost, slikari": "slikari",
        "general_knowledge": "opšte znanje"}


def citaj(putanja: str) -> list[dict]:
    wb = openpyxl.load_workbook(putanja, read_only=True)
    izlaz, vidjeno = [], set()
    for ws in wb.worksheets:
        struka = ws.title.split("-", 1)[1]
        struka = STRUKA.get(struka, struka)
        for i, red in enumerate(ws.iter_rows(values_only=True)):
            if i == 0:
                continue
            polja = [(str(x).strip() if x is not None else "") for x in red[:7]]
            if len(polja) < 7 or not all(polja):
                continue
            tema, tezina, pitanje, tacan, *netacni = polja
            odgovori = [tacan, *netacni]
            if len({o.lower() for o in odgovori}) < 4 or (struka, pitanje.lower()) in vidjeno:
                continue
            d = TEZINA.get(tezina.lower().replace("š", "s"))
            if not d:
                continue
            vidjeno.add((struka, pitanje.lower()))
            random.seed(pitanje)
            pomesano = odgovori[:]
            random.shuffle(pomesano)
            izlaz.append({"pozicija": struka, "question_text": pitanje, "options": pomesano,
                          "correct_answer": pomesano.index(tacan), "difficulty": d, "tags": [TEMA.get(tema, tema)]})
    return izlaz


if __name__ == "__main__":
    redovi = citaj(sys.argv[1])
    assert all(r["options"][r["correct_answer"]] for r in redovi)
    json.dump(redovi, open(sys.argv[2], "w"), ensure_ascii=False)
    print(len(redovi), "pitanja")
