import json, re, sys
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageOps
S, REPO = sys.argv[1], sys.argv[2]
svet = json.load(open(f"{REPO}/src/lib/osvajanje/svet.json"))
W, H = float(svet["sirina"]), float(svet["visina"])
# Boje timova iz aplikacije (teal, roze, ljubičasta, žuta, nebo, narandžasta) po kontinentu.
boje = {"sam": "#12907E", "jam": "#FF5FA2", "evr": "#6D4BC9", "afr": "#F4A33C", "azi": "#6EC3F2", "oke": "#E5385C"}
# Isto kao iOS Kontinenti.svi.
KONT = {"sam": ["sam", "kar"], "jam": ["jam"], "evr": ["sev", "zev", "jev", "iev"], "afr": ["saf", "zaf", "caf", "iaf", "jaf"],
        "azi": ["bli", "caz", "iaz", "jia"], "oke": ["oke"]}
reg_kont = {r: k for k, rs in KONT.items() for r in rs}
# Mapa visoke rezolucije: 3x
K = 3
mapa = Image.new("RGB", (int(W * K), int(H * K)), "#E3EDF2")
d = ImageDraw.Draw(mapa)
def poligoni(put):
    for deo in re.split(r"[Zz]", put):
        tacke = [(float(x) * K, float(y) * K) for x, y in re.findall(r"(-?[\d.]+),(-?[\d.]+)", deo)]
        if len(tacke) > 2: yield tacke
for o in svet["drzave"]:
    k = reg_kont.get(o["region"], "")
    boja = boje.get(k, "#CFEDE6")
    for p in poligoni(o["d"]):
        d.polygon(p, fill=boja, outline="#151515", width=2)
print("kontinenti:", sorted(set(reg_kont.values())))
psd = Image.open(f"{S}/mapa-mockup/Travel Maps Mockup/View 1.psd").convert("RGB")
siva = ImageOps.grayscale(psd)
# Papir = svetla oblast; pravougaonik iz maske.
# Papir je u sredini (pregled 1200 px: x 330–868, y 222–580); svetliji je od pozadine.
okvir = (1150, 760, 3350, 2260)
maska = Image.new("L", siva.size, 0)
maska.paste(siva.crop(okvir).point(lambda v: 255 if v > 227 else 0), okvir[:2])
x0, y0, x1, y1 = maska.getbbox()
print("papir", x0, y0, x1, y1)
pw, ph = x1 - x0, y1 - y0
platno = Image.new("RGB", (pw, ph), "#F3F0E6")
m = mapa.copy(); m.thumbnail((int(pw * 0.92), int(ph * 0.70)), Image.LANCZOS)
platno.paste(m, ((pw - m.width) // 2, int(ph * 0.22)))
dd = ImageDraw.Draw(platno)
f1 = ImageFont.truetype(f"{REPO}/mobile/fontovi/ArchivoBlack-Regular.ttf", int(ph * 0.085))
f2 = ImageFont.truetype(f"{REPO}/mobile/fontovi/SpaceGrotesk.ttf", int(ph * 0.035))
dd.text((pw // 2, int(ph * 0.08)), "OSVAJANJE SVETA", font=f1, fill="#151515", anchor="mm")
dd.text((pw // 2, int(ph * 0.155)), "171 država · šest vojski · znanje odlučuje bitku", font=f2, fill="#6F6C66", anchor="mm")
# Senke pregiba: svetlina papira (normalizovana na najsvetliji deo) množi dizajn.
papir = siva.crop((x0, y0, x1, y1)).convert("RGB")
max_v = max(papir.getextrema()[0][1], 1)
papir = papir.point(lambda v: min(255, int(v * 255 / max_v)))
dizajn = ImageChops.multiply(platno, papir)
izlaz = psd.copy(); izlaz.paste(dizajn, (x0, y0), maska.crop((x0, y0, x1, y1)))
izlaz.save(f"{S}/maketa-osvajanje.jpg", quality=90)
izlaz.resize((1500, 1000)).save(f"{S}/maketa-osvajanje-mala.jpg", quality=85)
