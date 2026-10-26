push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt
const largo = 9/7; const d0 = 0.5; const ntot = 100; const pasos = 10000
function distrib(L)
    e = largo + d0; mx = floor(Int, L/e)
    ntot <= mx && return ntot, 0
    ntot <= 2mx && return mx, ntot - mx
    return mx, mx
end
worker = parse(Int, ARGS[1]); nw = parse(Int, ARGS[2]); out = ARGS[3]
jobs = Tuple{String,Float64,Float64,Bool}[]
for inc in (false, true), ρ in (0.2, 0.47, 0.53, 0.87), ε in (0.0, 0.47, 0.89); push!(jobs, ("serie", ρ, ε, inc)); end
for inc in (false, true), ρ in (0.2, 0.47, 0.53, 0.87), ε in 0:0.05:1.0; push!(jobs, ("ego", ρ, ε, inc)); end
open(out, "w") do io
for (j, (tipo, ρ, ε, inc)) in enumerate(jobs)
    (j - 1) % nw == worker || continue
    L = ntot*(largo + d0)/(2ρ); n1, n2 = distrib(L)
    est = crear_estado(Parametros(L = L, egoismo = ε, incentivo_velocidad = inc), [n1, n2], [d0, d0])
    T, V, tc = medicion_velocidades_flujo_desplazamiento(est, pasos)
    vt = sum(V[5001:end])/5000*3.5; Q = count(>(500.0), tc)/500.0
    serie = tipo == "serie" ? join(round.(3.5 .* [sum(V[k:k+49])/50 for k in 1:50:pasos], digits = 3), ";") : ""
    println(io, join((tipo, ρ, ε, inc, vt, Q, serie), ",")); flush(io)
end
end
