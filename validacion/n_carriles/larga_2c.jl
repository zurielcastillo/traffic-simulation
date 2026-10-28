# Corridas largas (5000 s) de 2 carriles con el modelo revisado y el arranque de la tesis, para ver si el
# estado lento que deja el egoísmo se mantiene o termina regresando al flujo repartido.
#   ρ = 0.43, 0.45, 0.47, 0.51, 0.55   ε = 0, 0.89, 1   semillas 1 a 3 (misma perturbación que barrido_fino_2c.jl)
# Guarda la velocidad promedio (m/s) y los cambios de carril en ventanas de 50 s.
# Uso: julia larga_2c.jl <worker> <nworkers> <salida.csv>
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt, Random
const TO = TraficoOpt
const largo = 9/7; const d0 = 0.5; const ntot = 100; const PERT = 0.1
const PASOS = 50000; const VENTANA = 500   # 5000 s en ventanas de 50 s

""" parámetros del modelo revisado (los mismos que `filtros_reac` en corre_n.jl) """
modelo_revisado(; kw...) = parametros_experimentales(; modelo_aceleracion = :original, t_aviso_giro = 1.0,
                                                      mirar_dos_adelante = true, fraccion_necesidad = 0.95,
                                                      umbral_ganancia = largo, tiempo_entre_cambios = 5.0, kw...)

function corre(ρ, ε, semilla)
    L = ntot*(largo + d0)/(2ρ)
    mx = floor(Int, L/(largo + d0)); n1 = min(mx, ntot); n2 = ntot - n1   # arranque de la tesis
    est = crear_estado(modelo_revisado(L = L, egoismo = ε, d_0 = [d0, d0]), [n1, n2], [d0, d0])
    rng = MersenneTwister(semilla)
    for k in eachindex(est.vehs)
        a = est.vehs[k]
        est.vehs[k] = TO.Vehiculo(a.ancho, a.largo, a.pos[1], mod(a.pos[2] + PERT*(2rand(rng) - 1), L), k)
    end
    for k in eachindex(est.vehs); TO.actualiza_cache!(est, k); end
    orig = copy(est.origen); v = Float64[]; c = Int[]; sv = 0.0; sc = 0; choque = 0
    for t in 1:PASOS
        paso!(est)
        for i in eachindex(orig)
            est.origen[i] != orig[i] && (sc += 1; orig[i] = est.origen[i])
        end
        sv += velocidad_promedio_y(est)
        t % 50 == 0 && !isempty(choques(est)) && (choque += 1)
        if t % VENTANA == 0
            push!(v, round(sv/VENTANA*3.5, digits = 3)); push!(c, sc); sv = 0.0; sc = 0
        end
    end
    return "$ρ,$ε,$semilla,$choque,$(join(v, ";")),$(join(c, ";"))"
end

worker = parse(Int, ARGS[1]); nw = parse(Int, ARGS[2]); out = ARGS[3]
jobs = [(ρ, ε, s) for ρ in (0.43, 0.45, 0.47, 0.51, 0.55), ε in (0.0, 0.89, 1.0), s in 1:3]
open(out, "w") do io
    for (j, job) in enumerate(jobs)
        (j - 1) % nw == worker || continue
        println(io, corre(job...)); flush(io)
    end
end
