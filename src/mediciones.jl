# ---------------------------------------------------------------------------
# Mediciones (equivalentes a funciones_de_mediciones*.jl) y un carril
# ---------------------------------------------------------------------------

""" velocidad promedio en y (misma suma que el original: se suma un vector) """
velocidad_promedio_y(est::Estado) = sum([a.vel[2] for a in est.vehs])/length(est.vehs)

desplazamiento_auto(pa, pn, L) = (L - pa[2]) < (L - pn[2]) ? norma(V2(pn[1], L + pn[2]) - pa) : norma(pn - pa)
desplazamiento_auto_y(pa, pn, L) = (L - pa[2]) < (L - pn[2]) ? abs(L + pn[2] - pa[2]) : abs(pn[2] - pa[2])

"""
medicion_velocidades_flujo_desplazamiento(est, pasos)
igual que la función del original: devuelve T, V, tiempos_cruce, desplazamiento, desplazamiento_y
"""
function medicion_velocidades_flujo_desplazamiento(est::Estado, pasos)
    p = est.p; N = length(est.vehs)
    T = [t*p.δt for t in 1:pasos]; V = zeros(pasos)
    desplazamiento = zeros(pasos); desplazamiento_y = zeros(pasos)
    tiempos_cruce = Float64[]
    pos0 = [a.pos for a in est.vehs]
    des = zeros(N); des_y = zeros(N)
    for t in 1:pasos
        for i in 1:N; pos0[i] = est.vehs[i].pos; end
        for i in est.orden
            paso_auto!(est, i) && push!(tiempos_cruce, t*p.δt)
        end
        est.t += 1
        for i in est.orden
            des[i] = desplazamiento_auto(pos0[i], est.vehs[i].pos, p.L)
            des_y[i] = desplazamiento_auto_y(pos0[i], est.vehs[i].pos, p.L)
        end
        desplazamiento[t] = sum(des)/N; desplazamiento_y[t] = sum(des_y)/N
        V[t] = velocidad_promedio_y(est)
    end
    return T, V, tiempos_cruce, desplazamiento, desplazamiento_y
end

""" escribe un CSV sencillo (mismas columnas y nombres de archivo que el original) """
function escribir_csv(nombre, columnas::Vector{Pair{String,Vector{Float64}}})
    open(nombre, "w") do io
        println(io, join(first.(columnas), ","))
        n = length(last(columnas[1]))
        for k in 1:n
            println(io, join((string(c[k]) for c in last.(columnas)), ","))
        end
    end
    return nombre
end

"""
simular_y_guardar(pasos, p, n_por_carril; directorio)
corre la medición y guarda velocidad, flujo y desplazamiento con los nombres del original.
La densidad ρ es la misma fórmula del original generalizada: n_total*(largo + d_0[1])/(nc*L).
"""
function simular_y_guardar(pasos, p::Parametros, n_por_carril::Vector{Int}; largo = 9/7, ancho = 18/35, directorio = "")
    est = crear_estado(p, n_por_carril, fill(p.d_0[1], length(n_por_carril)); largo, ancho)
    T, V, tc, d, dy = medicion_velocidades_flujo_desplazamiento(est, pasos)
    ρ = sum(n_por_carril)*(largo + p.d_0[1])/(numero_carriles(p)*p.L)
    sufijo = "rho$(round(Int, 100*ρ))_epsilon$(round(Int, 100*p.egoismo)).csv"
    dir(x) = isempty(directorio) ? x : joinpath(directorio, x)
    escribir_csv(dir("velocidad_c_" * sufijo), ["tiempo" => T, "velocidad" => V])
    escribir_csv(dir("flujo_" * sufijo), ["tiempo_Flujo" => tc])
    escribir_csv(dir("desplazamiento_" * sufijo), ["tiempo" => T, "desplazamiento" => d, "desplazamiento_y" => dy])
    return T, V, tc, d, dy
end

# ------------------------------- un carril -------------------------------

"""
medicion_un_carril(ys, vs, largo, p, d_0, pasos)
un solo carril con las reglas de avance_en_un_carril.jl (el líder del auto j es el j+1).
`ys` y `vs` se modifican. Devuelve T, V, tiempos_cruce (igual que `medicion_un_carril_tiempo_vel_flujo`).
"""
function medicion_un_carril(ys::Vector{Float64}, vs::Vector{Float64}, largo, p::Parametros, d_0, pasos)
    M = length(ys); L = p.L; δt = p.δt
    T = [t*δt for t in 1:pasos]; V = zeros(pasos); tiempos_cruce = Float64[]
    for t in 1:pasos
        for idx in 1:M
            j = M - idx + 1
            jn = j < M ? j + 1 : 1
            Yn = ys[jn]; Yj = ys[j]
            sep = Yn > Yj ? Yn - Yj - largo : (Yn < Yj ? L - (Yj - Yn + largo) : 0.0)
            v = velocidad_prediccion(p, d_0, vs[j], vs[jn], sep, M == 1)
            vs[j] = v
            y = Yj + v*δt
            if y > L
                y -= L; push!(tiempos_cruce, t*δt)
            end
            ys[j] = y
        end
        V[t] = sum(vs)/M
    end
    return T, V, tiempos_cruce
end

""" posiciones iniciales de n autos en un carril (como `carros`) """
posiciones_iniciales(n, largo, Δx) = [largo/2 + (i-1)*(largo + Δx) for i in 1:n]
