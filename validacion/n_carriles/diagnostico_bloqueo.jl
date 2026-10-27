# Diagnóstico: busca el momento en que todos los autos quedan detenidos (bloqueo) y describe
# a los autos detenidos que están a medio cambio de carril y a quién tienen enfrente.
# Uso: julia diagnostico_bloqueo.jl <nc> <rho> <eps> <modelo>   (rho puede ser fracción: 10/15)
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt
const TO = TraficoOpt
const largo = 9/7; const d0 = 0.5; const ntot = 100

nc = parse(Int, ARGS[1]); ε = parse(Float64, ARGS[3]); modelo = ARGS[4]
ρ = eval(Meta.parse(ARGS[2]))   # acepta fracciones, p. ej. 10/15
L = ntot*(largo + d0)/(nc*ρ)
mx = floor(Int, L/(largo + d0)); ns = zeros(Int, nc); r = ntot
for k in 1:nc; ns[k] = min(mx, r); global r -= ns[k]; end
kw = (L = L, egoismo = ε, d_0 = fill(d0, nc))
p = modelo == "original" ? Parametros(; kw...) :
    modelo == "colisiones" ? parametros_experimentales(; modelo_aceleracion = :original, kw...) :
    parametros_experimentales(; kw...)
est = crear_estado(p, ns, fill(d0, nc))
N = length(est.vehs)
for t in 1:10000
    paso!(est)
    vm = velocidad_promedio_y(est)
    if t % 500 == 0 || vm < 1e-6
        println("t = $(t*p.δt) s  v promedio = $vm  girando = $(count(est.giro))")
    end
    if vm < 1e-6
        println("BLOQUEO en t = $(t*p.δt) s")
        for i in 1:N
            est.giro[i] || continue
            a = est.vehs[i]
            println("auto $i  x = $(round(a.pos[1], digits=3)) y = $(round(a.pos[2], digits=3))  origen $(est.origen[i]) destino $(TO.destino_efectivo(est, i))")
            for s in 1:2
                ℓ = est.f_carril[s, i]; k = TO.lider(est, i, ℓ); k == 0 && continue
                sk = TO.ranura(est, k, ℓ)
                sep = TO.separacion_dos_autos(est.f_y[s, i], est.f_largo[s, i], est.f_y[sk, k], est.f_largo[sk, k], L; con_signo = true)
                println("    carril $ℓ: líder $k (gira = $(est.giro[k])), separación $(round(sep, digits=3))")
            end
        end
        break
    end
end
