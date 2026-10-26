# Carga la versión ORIGINAL (carpeta version_original) sin Plots, para compararla con la nueva.
using LinearAlgebra, Statistics, Colors
macro animate(ex) :(nothing) end
plot(args...; kw...) = nothing
plot!(args...; kw...) = nothing
vline!(args...; kw...) = nothing
for f in ["estructuras_trafico.jl","funciones_iniciales.jl","funciones_principales.jl",
          "avance_en_un_carril.jl","fantasmas_dos_carriles.jl","velocidad_fantasmas_en_dos_carril.jl",
          "avance_carros_dos_carriles_sin_giro.jl","funciones_extras.jl",
          "funciones_cambio_de_carril_hacia_la_derecha.jl","funciones_cambio_de_carril_hacia_la_izquierda.jl",
          "Aux_dos_carriles_giro.jl","Aux_dos_carriles_giro_2.jl","funcion_detecta_choque.jl",
          "avance_carros_dos_carriles_con_giro.jl","funciones_de_mediciones.jl"]
    include(joinpath(@__DIR__, "version_original", f))
end
# parámetros globales que el código original necesita
δt = 0.1; d_0_1, d_0_2 = 0.5, 0.5; largo = 9/7; ancho = 18/35
α = 0.8; μ = 0.8; g = 2.803; T_reac = 1; acel = 1; colchon = 0.21
v_max = 4; v_min = 0.001
