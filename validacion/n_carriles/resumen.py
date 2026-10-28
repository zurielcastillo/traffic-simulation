# Resume y compara los barridos de n carriles de los distintos modelos.
# Uso: python resumen.py   (lee resultados.csv = original y partes/<modelo>_*.csv)
import csv, glob, json, os, statistics as st

AQUI = os.path.dirname(os.path.abspath(__file__))
COLS = ["nc", "rho", "eps", "inc", "N", "rho_real", "ns", "vt", "Q", "cambios", "pasos_choque",
        "pares", "t_choque1", "vneg", "ocup", "error", "prof_max", "pasos_grave", "pasos_mismo", "serie"]


def lee(rutas):
    filas = []
    for r in rutas:
        with open(r, encoding="utf8") as f:
            for x in csv.reader(f):
                if x[0] == "carriles":   # encabezado (solo en resultados.csv)
                    continue
                d = dict(zip(COLS, x))
                for k in ("nc", "N", "cambios", "pasos_choque", "pares", "vneg", "pasos_grave", "pasos_mismo"):
                    d[k] = int(d[k])
                for k in ("rho", "eps", "vt", "Q", "t_choque1", "prof_max"):
                    d[k] = float(d[k])
                filas.append(d)
    return filas


modelos = {"original": lee([os.path.join(AQUI, "resultados.csv")])}
for m in ("colisiones", "experimental", "reaccion05", "reaccion"):
    rutas = sorted(glob.glob(os.path.join(AQUI, "partes", f"{m}_*.csv")))
    if rutas:
        modelos[m] = lee(rutas)

# guarda todo junto en un json para la página de comparación
with open(os.path.join(AQUI, "comparacion.json"), "w", encoding="utf8") as f:
    json.dump({m: [{k: v for k, v in d.items()} for d in fs] for m, fs in modelos.items()}, f)


def clave(d):
    return (d["nc"], round(d["rho"], 4), round(d["eps"], 4))


for m, fs in modelos.items():
    print(f"\n=== {m}: {len(fs)} corridas ===")
    for nc in (2, 3, 4):
        g = [d for d in fs if d["nc"] == nc]
        if not g:
            continue
        choque = sum(d["pasos_choque"] > 0 for d in g)
        grave = sum(d["pasos_grave"] > 0 for d in g)
        err = sum(bool(d["error"]) for d in g)
        print(f"  {nc} carriles: {len(g)} corridas, con roce {choque} ({100*choque/len(g):.0f}%), "
              f"graves {grave} ({100*grave/len(g):.0f}%), prof. máx {max(d['prof_max'] for d in g):.3f}, errores {err}")

# tablas lado a lado: velocidad terminal (m/s) y flujo con ε = 0 y en ρ = 0.53 contra ε
idx = {m: {clave(d): d for d in fs} for m, fs in modelos.items()}
nombres = list(modelos)
for nc in (2, 3, 4):
    print(f"\n--- {nc} carriles, ε = 0: v terminal / Q / choque grave ---")
    print("rho    " + "  ".join(f"{m:>24}" for m in nombres))
    for k in range(1, 16):
        r = round(k/15, 4)
        celdas = []
        for m in nombres:
            d = idx[m].get((nc, r, 0.0))
            celdas.append(f"{d['vt']:6.2f} {d['Q']:5.2f} {'G' if d['pasos_grave'] else ('r' if d['pasos_choque'] else '-'):>2} {d['cambios']:6d}" if d else " " * 24)
        print(f"{r:5.3f}  " + "  ".join(f"{c:>24}" for c in celdas))
    print(f"--- {nc} carriles, ρ = 0.53 contra ε ---")
    for e in (0.0, 0.37, 0.47, 0.63, 0.79, 0.89):
        celdas = []
        for m in nombres:
            d = idx[m].get((nc, 0.5333, e))
            celdas.append(f"{d['vt']:6.2f} {d['Q']:5.2f} {'G' if d['pasos_grave'] else ('r' if d['pasos_choque'] else '-'):>2}" if d else "")
        print(f"ε={e:4.2f}  " + "  ".join(f"{c:>24}" for c in celdas))
