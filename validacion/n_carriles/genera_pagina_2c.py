# Genera validacion/resultados_2_carriles_experimental.html a partir de la plantilla y los datos.
# Uso: python genera_pagina_2c.py
#   1) python resumen.py                       (actualiza comparacion.json)
#   2) julia exporta_animacion_2c.jl 8/15 0.89 animacion_2c.js   (solo si cambió el modelo)
import json, os

AQUI = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(AQUI, "comparacion.json"), encoding="utf8"))
datos = {}
for m, fs in d.items():
    filas = []
    for x in fs:
        if x["nc"] != 2:
            continue
        r = {"r": round(x["rho"], 4), "e": round(x["eps"], 2), "v": round(x["vt"], 3), "q": round(x["Q"], 3),
             "c": x["cambios"], "pc": x["pasos_choque"], "pm": round(x["prof_max"], 3)}
        # las series de tiempo solo se guardan para las densidades y egoísmos de la figura
        if round(x["rho"], 2) in (0.47, 0.53, 0.87) and round(x["eps"], 2) in (0.0, 0.47, 0.89):
            r["s"] = [float(v) for v in x["serie"].split(";")]
        filas.append(r)
    datos[m] = filas
t = open(os.path.join(AQUI, "plantilla_2_carriles.html"), encoding="utf8").read()
anim = open(os.path.join(AQUI, "animacion_2c.js"), encoding="utf8").read()
t = t.replace("__DATA__", json.dumps(datos, separators=(",", ":"))).replace("__ANIM__", anim)
open(os.path.join(AQUI, "..", "resultados_2_carriles_experimental.html"), "w", encoding="utf8").write(t)
print("listo:", len(t), "bytes")
