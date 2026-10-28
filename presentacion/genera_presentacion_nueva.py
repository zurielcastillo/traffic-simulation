# Genera presentacion_modelo_nuevo.html: los pasos de la tesis con el modelo revisado (filtros_reac).
# Reutiliza el estilo, los autos y las gráficas de presentacion_tesis.html, y cambia los datos de dos
# carriles por los del modelo revisado.
# Uso:
#   1) python ../validacion/n_carriles/resumen.py   (actualiza comparacion.json)
#   2) julia exporta_animaciones_nuevo.jl heroe|duelo0|duelo9   (en la carpeta <anim>)
#   3) python genera_presentacion_nueva.py <anim>
import glob, json, os, re, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
NC = os.path.join(AQUI, "..", "validacion", "n_carriles")
ANIM = sys.argv[1]

orig = open(os.path.join(AQUI, "presentacion_tesis.html"), encoding="utf8").read()
css = orig[:orig.index("</style>") + len("</style>")]
css = css.replace("<title>Egoísmo al volante</title>", "<title>Egoísmo al volante, modelo revisado</title>")
codigo = orig[orig.index('<script src="https://cdnjs'):]
# la gráfica de velocidad en vivo del duelo: el rango de la tesis (2 a 6.5 m/s) no alcanza para ρ = 0.47
codigo = codigo.replace("const lo=2,hi=6.5", "const lo=0,hi=8").replace("for(const v of[3,4,5,6])", "for(const v of[2,4,6,8])")
assert "const lo=0,hi=8" in codigo

# datos de un carril: iguales a los de la tesis (el modelo revisado no cambia nada con un solo carril)
G_orig = json.loads(re.search(r"const G=(\{.*?\});\n", orig).group(1))
uno = {k: re.search(k + r":\{[^{}]*\}", orig).group(0) for k in ("uno2", "uno5", "uno8")}

# resultados de los barridos
d = json.load(open(os.path.join(NC, "comparacion.json"), encoding="utf8"))
def filas(modelo, nc):
    return [x for x in d[modelo] if x["nc"] == nc]
grueso = lambda x: abs(x["rho"]*15 - round(x["rho"]*15)) < 0.01
f2 = filas("filtros_reac", 2)
rho = sorted({round(x["rho"], 4) for x in f2 if grueso(x)})

def curva(fs, eps, campo):
    return [round(next(x for x in fs if grueso(x) and abs(x["rho"] - r) < 1e-3 and abs(x["eps"] - eps) < 1e-6)[campo], 3) for r in rho]
def ego(fs, r):
    return [[x["eps"], round(x["vt"], 3)] for x in sorted((x for x in fs if abs(x["rho"] - r) < 1e-6), key=lambda x: x["eps"])]
def serie(fs, r, eps):
    x = next(x for x in fs if abs(x["rho"] - r) < 1e-6 and abs(x["eps"] - eps) < 1e-6)
    return [float(v) for v in x["serie"].split(";")]

G = {"rho": rho, "uno": G_orig["uno"],
     "dos": {k: {"v": curva(f2, float(k), "vt"), "q": curva(f2, float(k), "Q")} for k in ("0.0", "0.37", "0.47", "0.63", "0.79", "0.89")},
     "ego": {k: ego(f2, float(k)) for k in ("0.2", "0.47", "0.53", "0.87")},
     "serie": {k: serie(f2, 0.47, float(k)) for k in ("0.0", "0.47", "0.89")},
     # comparación con la tesis (modelo original) para la sección "Antes y ahora"
     "antes": {k: ego(filas("original", 2), float(k)) for k in ("0.47", "0.53")}}

# 3 y 4 carriles con el modelo revisado (archivos filtros_reac34_* y filtros_reac4_*)
def lee_partes(patron):
    sys.path.insert(0, NC)
    from resumen import lee   # mismo lector que el resumen
    return lee(sorted(glob.glob(os.path.join(NC, "partes", patron))))
n = {}
for nc, patron in ((3, "filtros_reac34_*.csv"), (4, "filtros_reac4_*.csv")):
    fs = [x for x in lee_partes(patron) if x["nc"] == nc]
    n[nc] = fs
todas = f2 + n[3] + n[4]
G["n"] = {str(nc): {"v0": [round(x["vt"], 2) for x in sorted((x for x in fs if grueso(x) and x["eps"] == 0), key=lambda x: x["rho"])],
                    "q0": [round(x["Q"]/nc, 3) for x in sorted((x for x in fs if grueso(x) and x["eps"] == 0), key=lambda x: x["rho"])],
                    "ego47": ego(fs, 0.47), "ego53": ego(fs, 0.53),
                    "corridas": len(fs), "roce": sum(x["pasos_choque"] > 0 for x in fs),
                    "grave": sum(x["prof_max"] > 0.25 for x in fs)}
          for nc, fs in ((2, f2), (3, n[3]), (4, n[4]))}
# barrido fino de 2 carriles (validacion/n_carriles/barrido_fino_2c.jl): ρ, ε, semilla, v, Q, cambios, pasos con choque
import csv, statistics as st
fino = [dict(r=float(x[0]), e=float(x[1]), s=int(x[2]), v=float(x[3]), choque=int(x[6]))
        for f in sorted(glob.glob(os.path.join(NC, "fino", "parte_*.csv"))) for x in csv.reader(open(f, encoding="utf8"))]
rf = sorted({x["r"] for x in fino})
def perdida(e, r):
    # pérdida de cada semilla respecto a su propia corrida con ε = 0 (misma condición inicial)
    base = {x["s"]: x["v"] for x in fino if x["r"] == r and x["e"] == 0}
    return [100*(1 - x["v"]/base[x["s"]]) for x in fino if x["r"] == r and abs(x["e"] - e) < 1e-9 and x["s"] in base]
G["fino"] = {"rho": rf, "corridas": len(fino), "choques": sum(x["choque"] > 0 for x in fino),
             "eps": {k: {"media": [round(max(0, st.mean(perdida(float(k), r))), 1) for r in rf],
                         "min": [round(max(0, min(perdida(float(k), r))), 1) for r in rf],
                         "max": [round(max(0, max(perdida(float(k), r))), 1) for r in rf]}
                     for k in ("0.5", "0.7", "0.79", "0.89", "1.0")}}
graves = sum(x["prof_max"] > 0.25 for x in todas); roces = sum(x["pasos_choque"] > 0 for x in todas)

anim = {k: open(os.path.join(ANIM, k + ".js"), encoding="utf8").read() for k in ("heroe", "duelo0", "duelo9")}
A = "const A={" + ",".join([f"heroe:{anim['heroe']}"] + list(uno.values()) + [f"duelo0:{anim['duelo0']}", f"duelo9:{anim['duelo9']}"]) + "};"

def pct(a, b):
    return f"{round(100*(b - a)/a):+d} %".replace("-", "−")
v = lambda fs, r, e, c="vt": next(x for x in fs if abs(x["rho"] - r) < 1e-3 and abs(x["eps"] - e) < 1e-6)[c]
cuerpo = open(os.path.join(AQUI, "cuerpo_modelo_nuevo.html"), encoding="utf8").read()
cuerpo = (cuerpo.replace("__CAIDA47__", pct(v(f2, 7/15, 0.0), v(f2, 7/15, 0.79)))
                .replace("__CAIDAQ__", pct(v(f2, 7/15, 0.0, "Q"), v(f2, 7/15, 0.79, "Q")))
                .replace("__CAIDA53__", pct(v(f2, 0.53, 0.0), v(f2, 0.53, 1.0)))
                .replace("__NCHOQUES__", str(graves))
                .replace("__TXTCHOQUES__", f"choques graves en {len(todas)} corridas de 2, 3 y 4 carriles con el modelo revisado "
                                           f"(roces: {roces}). Con el modelo de la tesis, 44 a 49 % de las corridas de 3 y 4 carriles tenían choques graves")
                .replace("__SECCION_FINO__", open(os.path.join(AQUI, "seccion_rango.html"), encoding="utf8").read())
                .replace("__SECCION_N__", open(os.path.join(AQUI, "seccion_n_carriles.html"), encoding="utf8").read()))
extra = open(os.path.join(AQUI, "graficas_modelo_nuevo.js"), encoding="utf8").read()
html = css + "\n\n" + cuerpo + "\n\n<script>const G=" + json.dumps(G, separators=(",", ":")) + ";\n" + A + "</script>\n" + codigo.rstrip()
# las gráficas nuevas van en su propio bloque al final, después de Chart.js y del código de la tesis
html += "\n<script>\n" + extra + "\n</script>\n"
open(os.path.join(AQUI, "presentacion_modelo_nuevo.html"), "w", encoding="utf8").write(html)
print("listo:", len(html), "bytes; choques graves", graves, "de", len(todas), "; roces", roces)
