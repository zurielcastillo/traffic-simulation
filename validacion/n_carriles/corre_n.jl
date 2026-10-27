# Réplica de los experimentos de la tesis para n carriles (2, 3 y 4), registrando colisiones.
# Uso: julia corre_n.jl <worker> <nworkers> <salida.csv>
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt
const TO = TraficoOpt
const largo = 9/7; const d0 = 0.5; const ntot = 100; const pasos = 10000

""" llena los carriles en orden (como generar_distribucion_automatica, generalizado a nc carriles) """
function distrib(L, nc)
    mx = floor(Int, L/(largo + d0)); ns = zeros(Int, nc); r = ntot
    for k in 1:nc
        ns[k] = min(mx, r); r -= ns[k]
    end
    return ns
end

""" profundidad de penetración entre dos rectángulos (mínimo traslape sobre los ejes del SAT) """
function profundidad(e1, e2)
    m = Inf
    for esq in (e1, e2), i in 1:4
        ar = esq[mod1(i+1, 4)] - esq[i]; n = TO.V2(-ar[2], ar[1]); n = n/TO.norma(n)
        a1, b1 = TO.proyectar(e1, n); a2, b2 = TO.proyectar(e2, n)
        m = min(m, min(b1, b2) - max(a1, a2))
    end
    return m
end

""" corre la simulación midiendo velocidad, cruces, cambios de carril y colisiones """
function corre(nc, ρ, ε, inc)
    L = ntot*(largo + d0)/(nc*ρ)
    ns = distrib(L, nc)
    p = Parametros(L = L, egoismo = ε, incentivo_velocidad = inc, d_0 = fill(d0, nc))
    est = crear_estado(p, ns, fill(d0, nc))
    N = length(est.vehs)
    V = zeros(pasos); tc = Float64[]
    cambios = 0; pasos_choque = 0; pares = Set{Tuple{Int,Int}}(); t_choque1 = NaN
    prof_max = 0.0; pasos_grave = 0; pasos_mismo = 0
    vneg = 0; error_msg = ""; t_fin = pasos
    ocup = zeros(nc)                 # ocupación promedio por carril (500-1000 s)
    orig = copy(est.origen)
    try
        for t in 1:pasos
            for i in est.orden
                TO.paso_auto!(est, i) && push!(tc, t*p.δt)
            end
            est.t += 1
            for i in 1:N
                est.origen[i] != orig[i] && (cambios += 1; orig[i] = est.origen[i])
                est.vehs[i].vel[2] < 0 && (vneg += 1)
            end
            V[t] = velocidad_promedio_y(est)
            c = choques(est)
            if !isempty(c)
                pasos_choque += 1; isnan(t_choque1) && (t_choque1 = t*p.δt)
                union!(pares, c)
                grave = false; mismo = false
                for (i, j) in c
                    a, b = est.vehs[i], est.vehs[j]
                    dy = b.pos[2] - a.pos[2]; dy -= p.L*round(dy/p.L)
                    eb = ntuple(k -> b.esq[k] - TO.V2(0.0, (b.pos[2] - a.pos[2]) - dy), 4)
                    pr = profundidad(a.esq, eb); prof_max = max(prof_max, pr)
                    pr > 0.25 && (grave = true)
                    (!est.giro[i] && !est.giro[j] && est.origen[i] == est.origen[j]) && (mismo = true)
                end
                pasos_grave += grave; pasos_mismo += mismo
            end
            if t > 5000
                for i in 1:N; ocup[est.origen[i]] += 1; end
            end
        end
    catch e
        error_msg = sprint(showerror, e); t_fin = est.t
    end
    vt = t_fin >= pasos ? sum(V[5001:end])/5000*3.5 : NaN
    Q = t_fin >= pasos ? count(>(500.0), tc)/500.0 : NaN
    serie = join(round.(3.5 .* [sum(V[k:k+49])/50 for k in 1:50:pasos], digits = 3), ";")
    ocup ./= max(1, 5000)
    ρreal = N*(largo + d0)/(nc*L)
    return (nc, round(ρ, digits = 4), ε, inc, N, round(ρreal, digits = 4), join(ns, ";"), vt, Q, cambios,
            pasos_choque, length(pares), t_choque1, vneg, round.(ocup, digits = 2) |> x -> join(x, ";"),
            replace(error_msg, "," => " ", "\n" => " "), round(prof_max, digits = 4), pasos_grave, pasos_mismo, serie)
end

worker = parse(Int, ARGS[1]); nw = parse(Int, ARGS[2]); out = ARGS[3]
ρs = [k/15 for k in 1:15]
jobs = Tuple{Int,Float64,Float64,Bool}[]
for nc in (3, 4, 2), ε in (0.0, 0.37, 0.47, 0.63, 0.79, 0.89), ρ in ρs
    push!(jobs, (nc, ρ, ε, false))
end
for nc in (3, 4, 2), ρ in (0.2, 0.47, 0.53, 0.87), ε in 0:0.05:1.0
    any(j -> j[1] == nc && j[2] ≈ ρ && j[3] ≈ ε, jobs) && continue
    push!(jobs, (nc, ρ, ε, false))
end
# corridas para las series de tiempo (ε = 0.47 y 0.89 en las densidades de la figura)
for nc in (3, 4, 2), ρ in (0.47, 0.53, 0.87), ε in (0.47, 0.89)
    push!(jobs, (nc, ρ, ε, false))
end
length(ARGS) > 3 && (jobs = jobs[1:parse(Int, ARGS[4])])
open(out, "w") do io
    for (j, job) in enumerate(jobs)
        (j - 1) % nw == worker || continue
        r = corre(job...)
        println(io, join(r, ",")); flush(io)
    end
end
