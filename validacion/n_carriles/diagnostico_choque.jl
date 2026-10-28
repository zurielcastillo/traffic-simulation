# Diagnóstico: corre el modelo revisado (filtros_reac) hasta el primer choque y describe a los dos autos
# (posición, carril, si giran, velocidad, quién es su líder y qué separación ve cada uno), además de
# los 3 pasos anteriores al choque.
# Uso: julia diagnostico_choque.jl <nc> <rho> <eps>   (rho puede ser fracción: 8/15)
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt
const TO = TraficoOpt
const largo = 9/7; const d0 = 0.5; const ntot = 100

nc = parse(Int, ARGS[1]); ρ = eval(Meta.parse(ARGS[2])); ε = parse(Float64, ARGS[3])
L = ntot*(largo + d0)/(nc*ρ)
mx = floor(Int, L/(largo + d0)); ns = zeros(Int, nc); r = ntot
for k in 1:nc; ns[k] = min(mx, r); global r -= ns[k]; end
p = parametros_experimentales(; modelo_aceleracion = :original, t_aviso_giro = 1.0, fraccion_necesidad = 0.95,
                              fantasma_solo_si_ocupa = true, mirar_dos_adelante = true,
                              umbral_ganancia = largo, tiempo_entre_cambios = 5.0, L = L, egoismo = ε, d_0 = fill(d0, nc))
est = crear_estado(p, ns, fill(d0, nc))

""" describe al auto i: carril, giro, velocidad y la separación con su líder en cada carril que ocupa """
function describe(i)
    a = est.vehs[i]
    println("  auto $i: x=$(round(a.pos[1], digits=3)) y=$(round(a.pos[2], digits=3)) vy=$(round(a.vel[2], digits=3)) ",
            "origen=$(est.origen[i]) destino=$(est.destino[i]) giro=$(est.giro[i]) θ=$(round(est.θ[i], digits=4)) ",
            "toca carriles $(est.carril_lo[i])-$(est.carril_hi[i])")
    for s in 1:2
        ℓ = est.f_carril[s, i]; k = TO.lider(est, i, ℓ); k == 0 && continue
        sk = TO.ranura(est, k, ℓ)
        sep = TO.separacion_dos_autos(est.f_y[s, i], est.f_largo[s, i], est.f_y[sk, k], est.f_largo[sk, k], L; con_signo = true)
        println("     carril $ℓ: líder $k, separación $(round(sep, digits=3)), fantasma y=$(round(est.f_y[s, i], digits=3)) largo=$(round(est.f_largo[s, i], digits=3))")
    end
end

historia = Vector{String}()
for t in 1:10000
    paso!(est)
    c = choques(est)
    if !isempty(c)
        i, j = c[1]
        println("primer choque en t = $(t*p.δt) s entre los autos $i y $j")
        # también el líder de i, por si un tercer auto está "tapando" al de enfrente
        for s in 1:2
            k = TO.lider(est, i, est.f_carril[s, i]); k != 0 && k != j && (println("  líder de $i:"); describe(k))
        end
        describe(i); describe(j)
        # repite los últimos pasos desde cero para ver cómo se llegó ahí
        global est = crear_estado(p, ns, fill(d0, nc))
        for _ in 1:(t - 6); paso!(est); end
        for tt in (t - 5):t
            paso!(est); println("t = $(tt*p.δt) s"); describe(i); describe(j)
        end
        break
    end
end
