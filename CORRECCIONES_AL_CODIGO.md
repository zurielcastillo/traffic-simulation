# Correcciones al código y dónde está cada cambio

Este documento es la parte técnica. Las ideas del modelo revisado se explican en
[`CAMBIOS_AL_MODELO.md`](CAMBIOS_AL_MODELO.md).

Cada corrección y cada regla nueva es una opción de `Parametros` (`src/tipos.jl`) y viene **apagada**
por defecto. Con `Parametros()` el código da exactamente las mismas trayectorias que el modelo original
de la tesis. Se verificó corrida por corrida contra `validacion/n_carriles/resultados.csv`, y otra vez
después de agregar cada opción.

Unidades del código: 1 unidad de distancia = 3.5 m y el tiempo en segundos. Un auto mide
9/7 × 18/35 unidades.

## Cómo usar el modelo revisado

```julia
using TraficoOpt
p = parametros_experimentales(; modelo_aceleracion = :original,      # sin IDM
                              t_aviso_giro = 1.0,                     # cambio conceptual 2
                              fraccion_necesidad = 0.95,              # cambio conceptual 3
                              umbral_ganancia = 9/7,
                              tiempo_entre_cambios = 5.0,
                              mirar_dos_adelante = true,              # corrección 5
                              L = L, egoismo = ε, d_0 = fill(0.5, nc))
est = crear_estado(p, autos_por_carril, fill(0.5, nc))
```

`parametros_experimentales` prende las correcciones 1 a 4 y la aceleración IDM; aquí se apaga el IDM
y se agregan las demás. En los scripts es el modelo `filtros_reac`:

```bash
julia validacion/n_carriles/corre_n.jl <worker> <nworkers> <salida.csv> filtros_reac [limite] [carriles]
```

---

## Errores de programación corregidos

Con el código original, el 44 a 49 % de las corridas de 3 y 4 carriles terminaban con autos encimados
más de 90 cm, a veces uno dentro de otro. Con 2 carriles había roces de hasta 55 cm en un tercio de las
corridas.

### 1. La separación se calculaba en valor absoluto — `separacion_con_signo`

`separacion_dos_autos` devolvía `abs(sep)`. Si dos autos ya se enciman, la separación real es negativa,
pero la regla de velocidad recibía un número positivo y el auto de atrás no frenaba.

- **Arreglo.** La separación conserva su signo. Con separación negativa `velocidad_fantasma` y
  `velocidad_prediccion` devuelven 0, y `decide_cambiar` rechaza un hueco negativo.
- **Dónde.** `src/dinamica.jl`: `separacion_dos_autos`, `velocidad_fantasma` y
  `velocidad_prediccion`. Usos en `src/simulacion.jl` (`paso_auto!`, paso 1) y en
  `src/cambio_de_carril.jl` (`decide_cambiar`, `decide_cambiar_general`).

### 2. El líder se elegía por el centro del auto — `lider_por_fantasma`

El auto de enfrente se elegía por el centro del auto, pero la separación se medía con su fantasma en
ese carril. Con autos a medio cambio los dos órdenes no coinciden.

- **Arreglo.** El orden dentro del carril usa la posición del fantasma. Ya existía como opción en la
  rama `cambios_experimentales`.
- **Dónde.** `lider` en `src/cambio_de_carril.jl`.

### 3. Velocidad negativa hacia adelante — `velocidad_no_negativa`

Si la velocidad segura salía negativa, el auto avanzaba con la norma de esa velocidad.

- **Arreglo.** La velocidad mínima es 0.
- **Dónde.** `paso_auto!` en `src/simulacion.jl`, paso 2. Ya existía como opción.

### 4. El aviso de giro llegaba tarde — `no_cambiar_tras_auto_girando`

`giro[k]` se calcula en el paso 4 de `paso_auto!`, antes de que el auto se mueva en el paso 6. Un auto
que decidió cambiarse en este paso tenía `giro[k] = false` hasta su siguiente paso. Como los autos se
actualizan de adelante hacia atrás, todos los de un carril veían a su líder "sin girar" y decidían
cambiarse en el mismo paso.

- **Arreglo.** `cambiando(est, k) = est.giro[k] || est.θ[k] != 0`: un auto con ángulo de giro asignado
  ya cuenta como "cambiándose". La regla se aplica al líder en el carril actual y al auto de enfrente
  en el carril destino. Con esta opción, la regla original `giro[k]` se reemplaza por
  `percibe_cambio` (ver el cambio conceptual 2 abajo).
- **Dónde.** `cambiando`, `percibe_cambio` y `decide_cambiar_general` en `src/cambio_de_carril.jl`.
- **Efecto.** Es la corrección que más mueve los resultados. En 2 carriles, la caída de velocidad por
  egoísmo en ρ = 0.53 (de 5.3 a 3.7 m/s) se debía casi por completo a este error. Con solo esta
  corrección la velocidad queda en 5.3 m/s para cualquier ε (`validacion/n_carriles/aisla_correcciones.jl`).

### 5. Un fantasma de largo cero tapa al auto real — `mirar_dos_adelante`

Un auto que se cambia de carril cuenta en su carril de origen y en el destino. En el carril donde solo
asoma (o donde ya no está), `actualiza_cache!` le pone un fantasma de largo cero en su esquina
delantera. Ese fantasma puede quedar encima de otro auto del mismo carril. Como en el orden del carril
el auto real queda "detrás" del fantasma, el auto de atrás toma al fantasma como su líder, no ve al
auto real y choca con él. Pasa en los dos sentidos:

- **Auto que sale.** Ya está entero en el carril destino, pero todavía no termina de enderezarse, y su
  fantasma sigue en el carril de origen. Diagnóstico: `validacion/n_carriles/diagnostico_choque.jl 3
  0.53 0.89`, primer choque en t = 156.2 s entre los autos 53 y 55, tapados por el fantasma del 54.
- **Auto que entra.** Todavía está entero en su carril, y su fantasma en el carril destino quedó
  encima de un auto de ese carril. Mismo diagnóstico, t = 445.8 s, autos 35 y 36 tapados por el 62.

- **Arreglo.** En el paso 1 de `paso_auto!` el auto mira también al líder de su líder
  (`lider(est, k, ℓ)`) y frena por el que tenga la defensa trasera más cerca. Se descarta si está del
  otro lado del anillo (`abs(sep2) ≥ L/2`).
- **Dónde.** `paso_auto!` en `src/simulacion.jl`, paso 1.

### Probado y descartado: sacar al auto de su carril de origen — `fantasma_solo_si_ocupa`

Otra forma de evitar el caso del auto que sale es que deje de contar en su carril de origen en cuanto
ya no lo toca (`miembro` en `src/cambio_de_carril.jl`). Quita los choques, pero cambia mucho la
dinámica. Con 2, 3 y 4 carriles el tráfico se quedaba casi detenido en la mayoría de las densidades
medias; por ejemplo, en 2 carriles con ρ = 0.33 la velocidad terminal pasaba de 9.5 m/s a 0. La
opción se deja en el código, apagada, y el modelo revisado no la usa.

---

## Dónde está cada cambio conceptual

| Cambio conceptual | Parámetro | Valor en el modelo revisado | Código |
|---|---|---|---|
| 1. No cambiarse detrás de alguien que se cambia | `no_cambiar_tras_auto_girando` | `true` | `decide_cambiar_general` |
| 2. Tardar en notar el cambio del de enfrente | `t_aviso_giro` | `1.0` s | `percibe_cambio`; `Estado.t_decision` se llena en `paso_auto!`, paso 3 |
| 3a. Necesidad | `fraccion_necesidad` | `0.95` (apagado: `Inf`) | `quiere_cambiar` |
| 3b. Ganancia mínima | `umbral_ganancia` | `9/7` u (apagado: `0`) | `decide_cambiar_general` (`sep_cur + umbral > sep_t`) |
| 3c. Espera entre cambios | `tiempo_entre_cambios` | `5.0` s (apagado: `0`) | `quiere_cambiar`; `Estado.t_fin_cambio` se llena en `paso_auto!`, paso 5 |
| 4. Aceleración IDM (no usada) | `modelo_aceleracion = :idm`, `idm_a`, `idm_b`, `idm_b_max`, `idm_δ`, `idm_s0` | `:original` | `aceleracion_idm` y `velocidad_idm` en `src/dinamica.jl` |

Las funciones sin archivo están en `src/cambio_de_carril.jl`. Se agregaron dos campos a `Estado`
(`t_decision` y `t_fin_cambio`), inicializados en `crear_estado` (`src/simulacion.jl`).

## Scripts

| Archivo | Para qué |
|---|---|
| `validacion/n_carriles/corre_n.jl` | Barrido de la tesis para 2, 3 y 4 carriles. Modelos: `original`, `colisiones`, `experimental` (IDM), `reaccion`, `reaccion05`, `filtros`, `filtros_reac` (modelo revisado). |
| `validacion/n_carriles/resumen.py` | Junta los resultados en `comparacion.json` e imprime tablas. |
| `validacion/n_carriles/aisla_correcciones.jl` | Prende las correcciones 1 a 4 una por una. |
| `validacion/n_carriles/diagnostico_choque.jl` | Corre el modelo revisado hasta el primer choque y describe a los autos. |
| `validacion/n_carriles/diagnostico_bloqueo.jl` | Busca el momento en que todos se detienen. |
| `validacion/n_carriles/exporta_animacion_2c.jl` | Animación de frenado y aceleración de la página de 2 carriles. |
| `presentacion/exporta_animaciones_nuevo.jl` | Animaciones de la presentación con el modelo revisado. |
| `presentacion/genera_presentacion_nueva.py` | Genera `presentacion_modelo_nuevo.html`. |

## Barrido fino de densidad (2 carriles)

`validacion/n_carriles/barrido_fino_2c.jl` corre el modelo revisado con ρ = 0.35 a 0.65 en pasos de
0.02, ε = 0, 0.5, 0.7, 0.79, 0.89 y 1, y 5 semillas: 480 corridas. El modelo es determinista; cada
semilla mueve la posición inicial de cada auto hasta ±0.1 u (≈ 0.35 m). Resultados en
`validacion/n_carriles/fino/parte_*.csv` (ρ, ε, semilla, velocidad terminal en m/s, flujo, cambios de
carril, segundos con choque). La pérdida de velocidad se mide contra la corrida con ε = 0 de la misma
semilla.
