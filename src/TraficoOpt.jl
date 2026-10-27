"""
TraficoOpt: versión optimizada de la simulación de tráfico, generalizada a n carriles.

Reproduce las mismas reglas del modelo original (velocidad segura, autos fantasma,
cambio de carril con predicción y egoísmo). Con 2 carriles da las mismas
trayectorias que la versión original. Las ganancias de rapidez vienen de:
  * no recalcular fantasmas, orden y separaciones de TODOS los autos para cada auto
    (solo cambia el auto que se mueve, así que se mantiene un caché por auto),
  * predecir el carril destino en O(M) en lugar de O(M²),
  * tipos concretos (SVector) y sin variables globales.
"""
module TraficoOpt

using LinearAlgebra, StaticArrays

export Parametros, parametros_experimentales, Estado, crear_estado, paso!, simular!, simular_registro, velocidad_promedio_y, choques,
       medicion_velocidades_flujo_desplazamiento, simular_y_guardar, medicion_un_carril, posiciones_iniciales

include("tipos.jl")
include("geometria.jl")
include("dinamica.jl")
include("cambio_de_carril.jl")
include("simulacion.jl")
include("choques.jl")
include("mediciones.jl")

end
