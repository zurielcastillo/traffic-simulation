# Barrido fino de densidad en 2 carriles con el modelo revisado (filtros_reac), para ubicar con más
# precisión el rango de densidades donde el egoísmo baja la velocidad.
#   ρ = 0.35, 0.37, ..., 0.65   ε = 0, 0.5, 0.7, 0.79, 0.89, 1   semillas 1 a 5
# El modelo es determinista: cada semilla mueve al azar la posición inicial de cada auto hasta
# ±PERT unidades (0.1 u ≈ 0.35 m) a partir del arreglo de la tesis (se llena primero el carril 1).
# Uso: julia barrido_fino_2c.jl <worker> <nworkers> <salida.csv>
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt, Random
const TO = TraficoOpt
const largo = 9/7; const d0 = 0.5; const ntot = 100; const pasos = 10000; const PERT = 0.1

""" parámetros del modelo revisado (los mismos que `filtros_reac` en corre_n.jl) """
modelo_revisado(; kw...) = parametros_experimentales(; modelo_aceleracion = :original, t_aviso_giro = 1.0,
                                                      mirar_dos_adelante = true, fraccion_necesidad = 0.95,
                                                      umbral_ganancia = largo, tiempo_entre_cambios = 5.0, kw...)

""" una corrida: velocidad terminal (m/s, promedio de 500 a 1000 s), flujo, cambios de carril y choques """
function corre(ρ, ε, semilla)
    L = ntot*(largo + d0)/(2ρ)
    mx = floor(Int, L/(largo + d0)); n1 = min(mx, ntot); n2 = ntot - n1
    p = modelo_revisado(L = L, egoismo = ε, d_0 = [d0, d0])
    est = crear_estado(p, [n1, n2], [d0, d0])
    # perturbación de la posición inicial (solo en y, dentro del carril)
    rng = MersenneTwister(semilla)
    for k in eachindex(est.vehs)
        a = est.vehs[k]
        est.vehs[k] = TO.Vehiculo(a.ancho, a.largo, a.pos[1], mod(a.pos[2] + PERT*(2rand(rng) - 1), L), k)
    end
    for k in eachindex(est.vehs); TO.actualiza_cache!(est, k); end
    N = length(est.vehs); orig = copy(est.origen)
    vs = 0.0; cruces = 0; cambios = 0; pasos_choque = 0
    for t in 1:pasos
        for i in est.orden
            TO.paso_auto!(est, i) && t > 5000 && (cruces += 1)
        end
        est.t += 1
        for i in 1:N
            est.origen[i] != orig[i] && (cambios += 1; orig[i] = est.origen[i])
        end
        t > 5000 && (vs += velocidad_promedio_y(est))
        # revisar choques cada 10 pasos (1 s) basta para saber si hubo alguno y es 10 veces más barato
        t % 10 == 0 && !isempty(choques(est)) && (pasos_choque += 1)
    end
    return (round(ρ, digits = 2), ε, semilla, vs/5000*3.5, cruces/500, cambios, pasos_choque)
end

worker = parse(Int, ARGS[1]); nw = parse(Int, ARGS[2]); out = ARGS[3]
jobs = [(ρ, ε, s) for ρ in 0.35:0.02:0.65, ε in (0.0, 0.5, 0.7, 0.79, 0.89, 1.0), s in 1:5]
open(out, "w") do io
    for (j, job) in enumerate(jobs)
        (j - 1) % nw == worker || continue
        println(io, join(corre(job...), ",")); flush(io)
    end
end
