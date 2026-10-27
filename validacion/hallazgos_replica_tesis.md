# Hallazgos de la réplica de la tesis

Réplica hecha con el código optimizado (`src/`).

**Configuración**
- 100 autos, 10 000 pasos (δt = 0.1, 1000 s).
- Densidades ρ = k/15.
- Distribución inicial como `generar_distribucion_automatica`: se llena primero el carril 1.

**Mediciones**
- Velocidad terminal: promedio de 500 a 1000 s, en m/s (1 unidad = 3.5 m/s).
- Flujo terminal: cruces entre 500 y 1000 s.

Los valores de la tesis se leyeron a ojo de las figuras, así que son aproximados.

## 1. La condición de velocidad estaba apagada (dos carriles)

El texto de la tesis describe una condición de velocidad para cambiar de carril: el auto cambia solo si su velocidad es menor que el promedio del carril vecino. En el código original esa condición está desactivada (`velocidades_test_*` siempre devuelve `false`). Las figuras de dos carriles solo se reproducen con la condición apagada.

Comparación en ρ = 0.53:

| Caso | Tesis | Apagada | Prendida |
|---|---|---|---|
| v, ε = 0 | 4.8 | 5.28 | 5.29 |
| v, ε = 0.79 | ≈ 3.5 | 4.10 | 5.26 |
| v, ε = 0.89 | ≈ 3.4 | 3.71 | 5.26 |
| Q, ε = 0 | 0.90 | 0.90 | 0.90 |
| Q, ε = 0.63 | 0.82 | 0.88 | 0.90 |
| Q, ε = 0.79 | 0.67 | 0.70 | 0.89 |

Además, en ρ = 0.73 con ε = 0.79, el flujo es 0.49 en la tesis, 0.57 con la condición apagada y 0.64 con la condición prendida.

- Con la condición apagada se reproduce el efecto del egoísmo (Figuras 4.6 y 4.9): la velocidad y el flujo caen para ε alto en densidades intermedias.
- Con la condición prendida ese efecto casi desaparece. La velocidad en ρ = 0.53 queda en 5.3 m/s para cualquier ε.
- Con ε = 0 las dos versiones dan lo mismo y coinciden con la Figura 4.7. Por ejemplo: 11.9, 9.5 y 7.8 m/s en ρ = 0.27, 0.33 y 0.40. El flujo máximo es 1.02 autos/s en ρ = 0.33.
- En la tesis la caída por egoísmo empieza cerca de ε ≈ 0.65. Aquí empieza cerca de ε ≈ 0.75. La diferencia probablemente se debe al criterio de t_crit, porque la tesis usa suavizado y umbral de derivada y aquí se promedió una ventana fija.

**Acción sugerida:** corregir la sección de metodología de la tesis para decir que la condición de velocidad no se usa. O explicar que se probó y se descartó, porque en congestión el criterio relevante es el espacio libre.

## 2. Las figuras de un carril usan T_reac = 0.3 s, no 1 s

Con los parámetros de la Tabla 3.1 (T_reac = 1 s), las Figuras 4.2 y 4.4 no se reproducen. Con T_reac = 0.3 s se reproducen casi exacto:

| ρ | Q tesis | Q con T_reac = 1 | Q con T_reac = 0.3 |
|---|---|---|---|
| 0.067 | 0.195 | 0.20 | 0.20 |
| 0.33 | 0.745 | 0.51 | 0.75 |
| 0.47 | 0.787 | 0.48 | 0.79 |
| 0.67 | 0.742 | 0.38 | 0.74 |
| 0.87 | 0.575 | 0.24 | 0.58 |
| 1.00 | 0.372 | 0.13 | 0.37 |

Para la velocidad, la tesis tiene una meseta de 14 m/s hasta ρ ≈ 0.33 y 2.3 m/s en ρ = 1. Con T_reac = 0.3 s se obtiene lo mismo. Con T_reac = 1 s la meseta termina en ρ = 0.2 y en ρ = 1 la velocidad es 0.8 m/s.

**No es la velocidad máxima.** Probé v_max = 5, 6 y 8. Solo cambia la meseta de baja densidad, y para ρ ≥ 0.27 los resultados son iguales. Además, la meseta de 14 m/s de la figura corresponde a v_max = 4.

Las figuras de dos carriles sí cuadran con T_reac = 1 s. Entonces un carril y dos carriles se corrieron con tiempos de reacción distintos.

**Acción sugerida:** decidir qué valor es el correcto. Luego volver a correr la parte que no lo use, o declarar en la Tabla 3.1 el valor que se usó para un carril. Si se quiere comparar un carril contra dos carriles, ambos casos deben usar el mismo tiempo de reacción.

## 3. Detalle en la Figura 4.3

La leyenda de la figura dice:
- ρ = 0.20: azul
- ρ = 0.47: rojo
- ρ = 0.53: verde
- ρ = 0.87: amarillo

El pie de figura dice que 0.47 es amarillo, 0.53 rojo y 0.87 verde. Hay que corregir el pie.

## Archivos

- `validacion/replica_tesis.html`: comparación de dos carriles, con la condición apagada y prendida.
- `validacion/replica_tesis_un_carril.html`: comparación de un carril, con T_reac = 1 s y 0.3 s.
- `validacion/replica_tesis/`: scripts (`corre.jl`, `series.jl`) y resultados en CSV.
