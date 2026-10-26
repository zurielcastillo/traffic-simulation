# Punto de entrada de la versión optimizada (n carriles).
#   include("src/trafico.jl")
#   p   = Parametros(L = 110.0, egoismo = 0.8, d_0 = [0.5, 0.5])      # un d_0 por carril
#   est = crear_estado(p, [55, 45], [0.5, 1.1])                      # autos y separación inicial por carril
#   V, cruces = simular!(est, 10_000)
# Para animar: `using Plots; include("src/dibujo.jl"); anim = animacion!(est, 500; cada = 2); gif(anim, "trafico.gif")`
include(joinpath(@__DIR__, "TraficoOpt.jl"))
using .TraficoOpt
