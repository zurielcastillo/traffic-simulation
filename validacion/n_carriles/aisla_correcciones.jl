# Prende las correcciones de colisiones UNA POR UNA para ver cuál cambia el efecto del egoísmo.
# Uso: julia aisla_correcciones.jl <nc> <rho> <eps>   (rho puede ser fracción: 8/15)
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt
const largo = 9/7; const d0 = 0.5; const ntot = 100; const pasos = 10000

nc = parse(Int, ARGS[1]); ρ = eval(Meta.parse(ARGS[2])); ε = parse(Float64, ARGS[3])
L = ntot*(largo + d0)/(nc*ρ)
mx = floor(Int, L/(largo + d0)); ns = zeros(Int, nc); r = ntot
for k in 1:nc; ns[k] = min(mx, r); global r -= ns[k]; end

variantes = [
    "original"                     => (;),
    "solo separacion_con_signo"    => (separacion_con_signo = true,),
    "solo no_cambiar_tras_girando" => (no_cambiar_tras_auto_girando = true,),
    "solo lider_por_fantasma"      => (lider_por_fantasma = true,),
    "solo velocidad_no_negativa"   => (velocidad_no_negativa = true,),
    "todas (modelo colisiones)"    => (separacion_con_signo = true, no_cambiar_tras_auto_girando = true,
                                       lider_por_fantasma = true, velocidad_no_negativa = true),
]
for (nombre, kw) in variantes
    p = Parametros(; L = L, egoismo = ε, d_0 = fill(d0, nc), kw...)
    est = crear_estado(p, ns, fill(d0, nc))
    V, C = simular!(est, pasos)
    # velocidad terminal en m/s (promedio de 500 a 1000 s; 1 u/s = 3.5 m/s) y choques al final
    vt = sum(V[5001:end])/5000*3.5
    println(rpad(nombre, 32), " v terminal = ", round(vt, digits = 2), " m/s   choques al final = ", length(choques(est)))
end
