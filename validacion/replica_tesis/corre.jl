push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt
const largo = 9/7; const d0 = 0.5; const ntot = 100; const pasos = 10000
# distribución como distribucion_optima_carros del original
function distrib(L)
    e = largo + d0; mx = floor(Int, L/e)
    ntot <= mx && return ntot, 0
    ntot <= 2mx && return mx, ntot - mx
    return mx, mx   # los sobrantes se pierden (L_sugerido <= L+2)
end
worker = parse(Int, ARGS[1]); nw = parse(Int, ARGS[2]); out = ARGS[3]
ρs = [k/15 for k in 1:15]
jobs = Tuple{Int,Float64,Float64,Bool}[]
for ρ in ρs; push!(jobs, (1, ρ, 0.0, false)); end
for inc in (false, true), ε in (0.0, 0.37, 0.47, 0.63, 0.79, 0.89), ρ in ρs
    push!(jobs, (2, ρ, ε, inc))
end
open(out, "w") do io
for (j, (C, ρ, ε, inc)) in enumerate(jobs)
    (j - 1) % nw == worker || continue
    L = ntot*(largo + d0)/(C*ρ)
    if C == 1
        p = Parametros(L = L)
        ys = posiciones_iniciales(ntot, largo, d0); vs = zeros(ntot)
        T, V, tc = medicion_un_carril(ys, vs, largo, p, d0, pasos); nreal = ntot
    else
        n1, n2 = distrib(L)
        p = Parametros(L = L, egoismo = ε, incentivo_velocidad = inc)
        est = crear_estado(p, [n1, n2], [d0, d0])
        T, V, tc = medicion_velocidades_flujo_desplazamiento(est, pasos); nreal = n1 + n2
        ncamb = 0
    end
    vt = sum(V[5001:end])/5000*3.5
    Q = count(>(500.0), tc)/500.0
    println(io, join((C, round(ρ, digits=4), ε, inc, nreal, vt, Q), ",")); flush(io)
end
end
