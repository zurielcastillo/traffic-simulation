# Rama experimental: colisiones corregidas y aceleración IDM

Rama `experimental_colisiones_idm`, creada a partir de `version_estable` (el código de
`cambios_experimentales` más el barrido de 3 y 4 carriles).

Todas las correcciones son opcionales y vienen **apagadas** por defecto, así que `Parametros()`
sigue dando exactamente el modelo original (se verificó contra `n_carriles/resultados.csv`).
`parametros_experimentales()` las prende todas.

## Qué se cambió

| Opción | Qué corrige |
|---|---|
| `separacion_con_signo` | `separacion_dos_autos` devolvía `abs(sep)`. Un auto ya encimado recibía una separación positiva y no frenaba. Ahora la separación es negativa y el auto se detiene. |
| `no_cambiar_tras_auto_girando` | El original ya impedía empezar un cambio si el de enfrente en el carril actual estaba girando, pero `giro[k]` se actualiza antes de que el auto se mueva: un auto que decidió cambiar en ese mismo paso todavía aparece como "no girando". Resultado: un carril entero cambiaba de carril a la vez. Ahora se usa `cambiando(est, k)` (giro o ángulo de giro asignado) y la regla también se aplica al auto de enfrente en el carril destino. |
| `lider_por_fantasma`, `velocidad_no_negativa` | Ya existían; se prenden para que el signo de la separación sea consistente y nadie avance con velocidad negativa. |
| `modelo_aceleracion = :idm` | Intelligent Driver Model: aceleración máxima 1.05 m/s², frenado cómodo 2.1 m/s², frenado de emergencia 8.75 m/s², separación mínima 1.05 m. En el original un auto puede pasar de 14 m/s a 0 en 0.1 s. |

Para el barrido se comparan tres modelos con `validacion/n_carriles/corre_n.jl`:

- **original**: sin cambios.
- **colisiones**: las cuatro correcciones de colisiones, aceleración original.
- **experimental**: colisiones + IDM.

Mismas 537 corridas por modelo que el barrido anterior (100 autos, 1000 s). Resultados crudos en
`n_carriles/partes/` y `n_carriles/comparacion.json`; tablas con `python n_carriles/resumen.py`.

## 1. Las colisiones prácticamente desaparecen

Corridas con traslape grave (más de 0.25 u, unos 90 cm):

| Carriles | Original | Colisiones | Experimental (IDM) |
|---|---|---|---|
| 2 | 0 % (roces en 34 %) | 0 % (sin roces) | 0 % (sin roces) |
| 3 | 44 % | 1 % (1 corrida) | 1 % |
| 4 | 49 % | 0 % (roces leves en 5 %) | 4 % |

Con el IDM quedan algunos choques porque el frenado está acotado (como en la realidad, un auto no
siempre alcanza a frenar si alguien se le mete enfrente).

## 2. Con ε = 0 la velocidad casi no cambia

Velocidad terminal (m/s), ε = 0:

| ρ | 2 c. original | 2 c. colisiones | 2 c. IDM | 3 c. original | 3 c. colisiones | 3 c. IDM |
|---|---|---|---|---|---|---|
| 0.27 | 11.9 | 11.9 | 12.2 | 8.0 | 8.0 | 9.7 |
| 0.40 | 7.8 | 7.8 | 9.6 | 7.7 | 7.7 | 9.3 |
| 0.53 | 5.3 | 5.3 | 6.1 | 5.2 | 5.3 | 5.6 |
| 0.67 | 3.6 | 3.6 | 3.8 | 3.5 | 3.3 | 4.1 |
| 0.80 | 2.3 | 2.3 | 2.4 | 2.3 | 2.2 | 2.3 |

Las correcciones de colisiones no mueven el diagrama fundamental con cooperación total. El IDM da
velocidades y flujos más altos en densidad media (flujo máximo de 2 carriles: 1.23 contra 1.02 autos/s),
porque deja seguir más cerca a velocidad constante.

## 3. Hallazgo importante: el efecto del egoísmo en 2 carriles viene del cambio simultáneo

Velocidad terminal (m/s) en 2 carriles contra ε:

| ρ | Modelo | ε = 0 | 0.63 | 0.79 | 0.89 |
|---|---|---|---|---|---|
| 0.53 | original | 5.3 | 5.2 | 4.1 | 3.7 |
| 0.53 | colisiones | 5.3 | 5.3 | 5.3 | 5.3 |
| 0.73 | original | 2.9 | 2.8 | 2.4 | 2.0 |
| 0.73 | colisiones | 2.9 | 2.9 | 2.9 | 2.9 |

Con las correcciones, la caída de velocidad por egoísmo **desaparece por completo en 2 carriles**.
Prendiendo las correcciones una por una (`n_carriles/aisla_correcciones.jl 2 8/15 0.89`):

| Variante | v terminal (m/s) |
|---|---|
| original | 3.71 |
| solo separación con signo | 3.70 |
| solo líder por fantasma | 3.71 |
| solo velocidad no negativa | 3.72 |
| **solo no cambiar tras auto girando** | **5.30** |

Es decir, el resultado central de 2 carriles (el egoísmo baja el flujo) depende de que varios autos
seguidos empiecen a cambiar de carril en el mismo paso, algo que la propia regla del modelo quería
impedir. Con 3 carriles el efecto del egoísmo sí se mantiene (en ρ = 0.53: 5.3 → 3.9 → 1.8 m/s para
ε = 0, 0.79, 0.89), aunque empieza más tarde que en el original.

**Acción sugerida:** decidir si los cambios simultáneos son parte del modelo (y entonces decirlo en la
tesis, porque es lo que produce el efecto) o un error (y entonces el efecto del egoísmo en 2 carriles
tiene que buscarse con otra regla de cambio de carril, ver propuestas).

## 4. El IDM todavía se traba con 3 y 4 carriles

Con 3 y 4 carriles hay densidades en las que todo se detiene (con ε = 0: 3 carriles en ρ = 0.60 y 0.73,
4 carriles en ρ = 0.80) y, con 4 carriles, la velocidad queda por debajo de 1.5 m/s desde ρ = 0.53.
Con egoísmo pasa lo mismo: en 3 carriles y ρ = 0.53 la velocidad cae a 1.4 m/s ya con ε = 0.47. La regla de cambio de carril sigue pidiendo la distancia segura de la
tesis, que es mucho mayor que el hueco con el que el IDM sigue a otro auto. Los autos quedan a medio
cambio sin poder terminarlo ni regresar. El IDM necesita una regla de cambio de carril hecha para él
(MOBIL, propuesta 1) antes de usarse en 3 y 4 carriles.

## Propuestas de cambios al modelo

1. **Cambio de carril tipo MOBIL** (Kesting, Treiber y Helbing, 2007). Es la pareja natural del IDM: se
   cambia si la ganancia de aceleración propia supera a la pérdida que se causa a los demás multiplicada
   por un factor de cortesía p. Ese p es exactamente el egoísmo de la tesis (ε ≈ 1 - p), así que el tema
   central se conserva con una regla estándar y citable. También incluye un umbral que quita los miles
   de cambios de carril a baja densidad (8 229 con 4 carriles en ρ = 0.07).
2. **Poder abortar un cambio de carril.** Si el auto queda detenido a medio cambio, que regrese a su
   carril. Hoy se queda bloqueando dos carriles, que es lo que traba el IDM.
3. **Condición inicial aleatoria y varias semillas.** Hoy se llena primero el carril 1, lo que deja
   carriles vacíos (el carril 3 casi sin usar con 3 carriles) y hace que cada punto dependa de una sola
   corrida. Con 10 semillas por punto se pueden poner barras de error en las figuras.
4. **Conductores distintos.** Repartir v_max y el tiempo de reacción entre los autos (por ejemplo ±10 %).
   Con autos idénticos el anillo tiende a un estado perfectamente ordenado que no se ve en la realidad.
5. **Ruido o "distracción".** Un frenado aleatorio pequeño (como en Nagel-Schreckenberg) genera los
   embotellamientos fantasma que se ven en las carreteras y permite estudiar si el egoísmo los empeora.
6. **Regla de mantenerse a la derecha.** Obligar a regresar al carril derecho cuando hay espacio, como
   marca el reglamento. Daría un uso de carriles asimétrico, más realista que el actual.
7. **Mismo tiempo de reacción para 1 y 2 carriles** (pendiente del hallazgo 2 de
   `hallazgos_replica_tesis.md`), para poder comparar ambos casos.
8. **Cuello de botella.** Un tramo donde se pierde un carril (de 3 a 2) en lugar del anillo uniforme.
   Es donde más se nota el egoísmo en la práctica y daría una figura nueva para la tesis.

## 5. Tiempo de reacción y filtros de cambio realista (2 carriles)

Dos opciones nuevas, apagadas por defecto:

- `t_aviso_giro`: el auto de atrás nota que el de enfrente empezó a cambiar de carril hasta después
  de este tiempo (1 s en las pruebas). Con 0 se nota al instante, como en el modelo "colisiones".
- Filtros que se revisan ANTES de la regla de egoísmo ε, que no cambia:
  `fraccion_necesidad = 0.95` (solo busca otro carril si va a menos del 95 % de v_max),
  `umbral_ganancia = 9/7` (el otro carril debe tener al menos un largo de auto más de hueco) y
  `tiempo_entre_cambios = 5` s (espera mínima entre un cambio y el siguiente).

Modelos en `corre_n.jl`: `reaccion` (1 s), `reaccion05` (0.5 s), `filtros` y `filtros_reac`.

| Caso | Original | Colisiones | Reacción 1 s | Filtros + reacción |
|---|---|---|---|---|
| ρ = 0.2, ε = 0: v (m/s) / cambios | 14.0 / 150 | 14.0 / 50 | 7.8 / 4 400 | 14.0 / 230 |
| ρ = 0.47, ε = 0.9 | 6.4 | 6.4 | 1.4 | 4.0 |
| ρ = 0.53, ε = 0.8 | 3.7 | 5.3 | 0.9 | 4.9 |
| ρ = 0.53, ε = 1.0 | 3.6 | 5.3 | 1.0 | 3.4 |
| ρ = 0.87, ε = 0.9 | 1.4 | 1.7 | 0.9 | 1.7 |

- Solo con el tiempo de reacción, el efecto del egoísmo regresa muy exagerado y aparece un vaivén de
  pelotones a baja densidad: todo el pelotón se cambia de carril y luego regresa.
- Con los filtros y la reacción se quita el vaivén, el diagrama con ε = 0 queda prácticamente igual
  al original y el egoísmo baja la velocidad en densidad media, de forma parecida a la tesis.
  No hay choques en ninguna corrida.
- Los filtros sin reacción dan lo mismo que "colisiones" (sin efecto del egoísmo).

## 6. Modelo revisado final (`filtros_reac`, con `mirar_dos_adelante`)

Con la versión anterior quedaban 6 corridas de 3 carriles con choques graves. La causa era un fantasma
de largo cero encimado con un auto real que lo tapaba para el de atrás (detalle en
`CORRECCIONES_AL_CODIGO.md`, corrección 5). Con `mirar_dos_adelante` el barrido de 537 corridas
(2, 3 y 4 carriles) no tiene **ningún choque ni roce**.

| Caso (velocidad terminal, m/s) | Original | Revisado |
|---|---|---|
| 2 carriles, ρ = 7/15 ≈ 0.467, ε = 0 → 0.79 | 6.4 → 6.4 | 6.4 → 3.0 |
| 2 carriles, ρ = 0.53, ε = 0 → 1 | 5.3 → 3.6 | 5.3 → 3.8 |
| 2 carriles, ρ = 0.87, ε = 0 → 1 | 1.7 → 1.3 | 1.7 → 1.6 |
| 3 carriles, ρ = 0.53, ε = 0 → 1 | 5.3 → 1.5 (con choques) | 5.3 → 2.4 |
| 4 carriles, ρ = 0.53, ε = 0 → 1 | 5.3 → 1.7 (con choques) | 5.3 → 0.9 |

Pendiente con 3 y 4 carriles: a baja densidad algunos carriles casi no se usan, porque todos los
autos arrancan en el carril 1, y la corrida de 4 carriles con ρ = 0.73 y ε = 0 se atora (0.3 m/s).

## 7. El efecto del egoísmo depende de la condición inicial (2 carriles, modelo revisado)

Barrido fino (`n_carriles/barrido_fino_2c.jl`, ρ = 0.35 a 0.65, 5 semillas) con tres arranques:

| Arranque | Cambios de carril por corrida | Rango con pérdida ≥ 10 % (ε ≥ 0.7) | Mayor pérdida |
|---|---|---|---|
| Tesis: se llena el carril 1, el 2 queda casi vacío (`fino/`) | ≈ 330 | ρ ≈ 0.41 a 0.57 | 36 % (ρ = 0.45, ε = 1) |
| 50 y 50 al azar, hasta ±45 % del espacio entre autos (`fino_desorden/`) | < 3 | ninguno | < 1 % |
| 50 y 50 espaciados parejo, ±0.35 m (`fino_uniforme/`) | 0 | ninguno | 0 % |

Con ε = 0 la velocidad terminal es la misma en los tres arranques. En el modelo revisado el egoísmo
solo pesa cuando hay un desbalance fuerte entre carriles que obliga a muchos cambios de carril. Con
los carriles igual de llenos, el seguimiento empareja los huecos y casi nadie tiene motivo para
cambiarse. Falta revisar si el modelo original de la tesis también depende así del arranque.
