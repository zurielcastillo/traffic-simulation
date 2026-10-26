# 🚦 Simulación de Tráfico Vehicular con Cambio de Carriles

Versión optimizada y generalizada a **n carriles**. Con 2 carriles da **exactamente las mismas trayectorias** que la versión anterior (verificado bit a bit) y corre unas **500 veces más rápido**. La versión anterior está en `validacion/version_original/`.

## 📦 Dependencias

```julia
using Pkg
Pkg.add(["StaticArrays"])          # necesario
Pkg.add(["Plots"])                 # solo para dibujar y animar
```

## 🚀 Inicio rápido

```julia
include("src/trafico.jl")

p   = Parametros(L = 110.0, egoismo = 0.8, d_0 = [0.5, 0.5])   # un valor de d_0 por carril → 2 carriles
est = crear_estado(p, [55, 45], [0.5, 1.1])                   # autos y separación inicial de cada carril
V, cruces = simular!(est, 10_000)                             # velocidad promedio y cruces por y = L en cada paso
```

Para 4 carriles basta con dar 4 valores: `Parametros(d_0 = fill(0.5, 4))` y `crear_estado(p, [40, 30, 20, 10], [0.5, 1.0, 2.0, 4.0])`.

### 🎥 Animación

```julia
using Plots
include("src/dibujo.jl")
anim = animacion!(est, 1000; cada = 2)     # un cuadro cada 2 pasos
gif(anim, "trafico.gif", fps = 20)
```

### 📊 Mediciones

```julia
T, V, tiempos_cruce, desplazamiento, desplazamiento_y = medicion_velocidades_flujo_desplazamiento(est, pasos)
simular_y_guardar(pasos, p, [55, 45])      # guarda los CSV con los mismos nombres que antes
T, V, tiempos_cruce = medicion_un_carril(posiciones_iniciales(50, 9/7, 0.8), zeros(50), 9/7, Parametros(d_0 = [0.5]), 0.5, pasos)
```

`choques(est)` devuelve los pares de autos que se enciman (también revisa la frontera periódica).

## ⚙️ Parámetros (`Parametros`)

| Campo | Valor por defecto | Significado |
|---|---|---|
| `δt` | 0.1 | paso de tiempo (s) |
| `d_0` | `[0.5, 0.5]` | separación mínima de cada carril; su largo es el número de carriles |
| `α`, `μ`, `g` | 0.8, 0.8, 2.803 | visibilidad, fricción, gravedad (9.81 m/s² / 3.5) |
| `T_reac`, `acel`, `colchon` | 1, 1, 0.21 | tiempo de reacción, aceleración base, margen numérico |
| `v_max`, `v_min` | 4, 0.001 | velocidades límite |
| `L` | 110 | largo de la pista circular |
| `egoismo` | 0.8 | 0 a 1 |
| `incentivo_velocidad` | `false` | en la versión anterior la condición de velocidad para cambiar de carril estaba desactivada |
| `velocidad_no_negativa` | `false` | corrección opcional (ver abajo) |
| `lider_por_fantasma` | `false` | corrección opcional (ver abajo) |

Con todas las opciones en `false` se reproduce el modelo anterior tal cual.

**Correcciones opcionales.** Al validar se encontraron dos causas de choques que vienen del modelo anterior:
1. Si la velocidad segura sale negativa (el auto ya no alcanza a frenar), el auto avanza con la *norma* de esa velocidad, es decir, hacia adelante. `velocidad_no_negativa = true` lo detiene.
2. El auto de enfrente se elige por el centro del auto, pero la distancia se mide con su fantasma. Un auto que sale del carril deja un fantasma de largo cero en su esquina delantera y puede ocultar al verdadero auto de enfrente. `lider_por_fantasma = true` ordena por la posición del fantasma.

Con 2 carriles casi no ocurren; con 3 o más carriles son más frecuentes.

## 🔄 Escala

1 unidad = 3.5 m. Largo del auto 9/7 (4.5 m), ancho 18/35 (1.8 m).
La velocidad está en unidades/s, así que **v [km/h] = v × 3.5 × 3.6 = 12.6·v** (v_max = 4 ≈ 50 km/h).

## ✅ Validación

```bash
julia validacion/comparar.jl 300        # corre las dos versiones y compara paso a paso
```

`validacion/validacion_2_carriles.html` tiene la animación y las gráficas de las dos versiones con 3000 pasos.

## 🧭 Generalización a n carriles

Las reglas son las mismas que con 2 carriles. Lo que se tuvo que decidir para n > 2:
- Un auto en un carril intermedio evalúa los dos carriles vecinos y prueba primero el que tiene más espacio enfrente.
- El destino del cambio se fija cuando empieza el giro; durante el giro el auto cuenta en su carril de origen y en el de destino (como antes).
- El orden de actualización alterna los carriles igual que `generar_indices_alternados`.
