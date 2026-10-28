# ---------------------------------------------------------------------------
# Inicialización, paso de simulación y mediciones
# ---------------------------------------------------------------------------

"""
crear_estado(p, n_por_carril, separaciones; largo, ancho, xs)
acomoda n_por_carril[k] autos en el carril k separados separaciones[k] (como `carros_dos_carriles`).
"""
function crear_estado(p::Parametros, n_por_carril::Vector{Int}, separaciones::Vector{Float64};
                      largo = 9/7, ancho = 18/35, xs = 1/2)
    nc = numero_carriles(p)
    length(n_por_carril) == nc == length(separaciones) || error("n_por_carril, separaciones y p.d_0 deben tener un valor por carril")
    vehs = Vehiculo[]
    for k in 1:nc
        n = n_por_carril[k]; Δx = separaciones[k]
        n*largo + (n-1)*Δx > p.L && error("No hay espacio suficiente para los autos en el carril $k")
        x = k == 1 ? xs : xs + (k-1)*p.ancho_carril
        for i in 1:n
            push!(vehs, Vehiculo(ancho, largo, x, largo/2 + (i-1)*(largo + Δx), length(vehs) + 1))
        end
    end
    N = length(vehs)
    est = Estado(p, nc, vehs, falses(N), zeros(N), zeros(Int, N), zeros(Int, N),
                 indices_alternados(n_por_carril), zeros(Int, N), zeros(Int, N),
                 zeros(Int, 2, N), zeros(2, N), zeros(2, N), zeros(2, N), 0, fill(typemin(Int), N), fill(typemin(Int), N),
                 Int[], Float64[], Float64[], Float64[])
    for k in 1:N
        a = vehs[k]
        est.giro[k] = !(abs(a.dir[1]) < p.err_dir && abs(1 - a.dir[2]) < p.err_dir)
        lo, hi = carriles_que_toca(p, nc, a)
        est.origen[k] = hi; est.destino[k] = hi
    end
    for k in 1:N
        actualiza_cache!(est, k)
    end
    return est
end

""" orden de actualización: [n1, n1+n2, ..., n1-1, ...] alternando carriles (como `generar_indices_alternados`) """
function indices_alternados(ns::Vector{Int})
    inicios = cumsum([0; ns[1:end-1]])
    bloques = [collect((inicios[k] + ns[k]):-1:(inicios[k] + 1)) for k in eachindex(ns)]
    orden = Int[]
    for r in 1:maximum(ns; init = 0), b in bloques
        r <= length(b) && push!(orden, b[r])
    end
    return orden
end

""" avanza el auto i (las mismas etapas que `avance_dos_carriles_con_giro_un_paso`) """
function paso_auto!(est::Estado, i)
    p = est.p; a = est.vehs[i]; L = p.L
    lo0, hi0 = est.carril_lo[i], est.carril_hi[i]

    # 1) velocidad segura de cada fantasma del auto con su líder en ese carril
    vf = (est.f_vy[1, i], est.f_vy[2, i])
    for s in 1:2
        ℓ = est.f_carril[s, i]
        k = lider(est, i, ℓ)
        k == 0 && continue
        sk = ranura(est, k, ℓ)
        mismo = k == i
        # con `separacion_con_signo` la separación sale negativa si los autos ya se enciman y la
        # regla de velocidad lo detiene (en el original, abs(sep) lo dejaba seguir avanzando)
        sep = separacion_dos_autos(est.f_y[s, i], est.f_largo[s, i], est.f_y[sk, k], est.f_largo[sk, k], L;
                                   mismo, con_signo = p.separacion_con_signo)
        v = velocidad_fantasma(p, p.d_0[ℓ], est.f_vy[s, i], est.f_largo[s, i], est.f_vy[sk, k], sep, mismo)
        vf = s == 1 ? (v, vf[2]) : (vf[1], v)
    end

    # 2) velocidad real: el mínimo si está girando, si no la de su carril
    if est.giro[i]
        o = est.origen[i]; d = destino_efectivo(est, i)
        v_lo = vf[ranura(est, i, min(o, d))]; v_hi = vf[ranura(est, i, max(o, d))]
        a.vel = V2(a.vel[1], min(v_lo, v_hi))
    elseif lo0 == hi0
        a.vel = V2(a.vel[1], vf[ranura(est, i, lo0)])
    end

    if p.velocidad_no_negativa && a.vel[2] < 0
        a.vel = V2(a.vel[1], 0.0)
    end

    # 3) ángulo de giro
    if !est.giro[i]
        o = est.origen[i]
        candidatos = est.destino[i] != o ? (est.destino[i],) :
                     (o > 1 && o < est.nc) ? (o - 1, o + 1) : (o > 1 ? (o - 1,) : (o < est.nc ? (o + 1,) : ()))
        # filtros experimentales antes de buscar carril (ver `quiere_cambiar`): si el auto no tiene
        # motivo para cambiarse, o acaba de cambiarse, ni siquiera evalúa los carriles vecinos
        if est.destino[i] == o && !quiere_cambiar(est, i)
            candidatos = ()
        end
        if length(candidatos) == 2
            # con dos opciones se evalúa primero el carril con más espacio enfrente
            s1 = hueco_enfrente(est, i, candidatos[1], 1); s2 = hueco_enfrente(est, i, candidatos[2], 2)
            candidatos = s2 > s1 ? (candidatos[2], candidatos[1]) : candidatos
        end
        for t in candidatos
            pre = maximo_giro(a)/100
            pre = correccion_angulo!(a, pre, frontera(p, o, t), centro_destino(p, o, t), p)
            if decide_cambiar_general(est, i, pre, o, t)
                est.θ[i] = pre
                est.destino[i] = t
                est.t_decision[i] = est.t   # para saber desde cuándo los demás lo pueden notar
                break
            end
        end
    else
        o = est.origen[i]; d = destino_efectivo(est, i)
        θ = maximo_giro(a)/100
        est.θ[i] = correccion_angulo!(a, θ, frontera(p, o, d), centro_destino(p, o, d), p)
    end

    # 4) ¿sigue girando?
    est.giro[i] = !(abs(a.dir[1]) < p.err_dir && abs(1 - a.dir[2]) < p.err_dir)
    if est.giro[i] && est.destino[i] == est.origen[i]
        # empezó a girar sin destino asignado: se fija ahora (con 2 carriles siempre es el otro carril)
        est.destino[i] = destino_efectivo(est, i)
    end

    # 5) si terminó el cambio, el carril nuevo pasa a ser el de origen
    if !est.giro[i] && lo0 == hi0 && lo0 != est.origen[i]
        est.origen[i] = lo0; est.destino[i] = lo0
        est.t_fin_cambio[i] = est.t   # para `tiempo_entre_cambios`
    end

    # 6) mover y condición periódica
    velocidad_angular_carro_correcion!(a, p.δt, est.θ[i])
    cruzo = limites_auto_carril!(a, L)
    actualiza_cache!(est, i)
    return cruzo
end

""" hueco con el fantasma de enfrente en el carril t (solo para ordenar candidatos con n > 2 carriles) """
function hueco_enfrente(est::Estado, i, t, esquina_lado)
    idx, ys, ls, vs = est.buf_idx, est.buf_y, est.buf_l, est.buf_v
    M = lista_carril!(idx, ys, ls, vs, est, t)
    M == 0 && return Inf
    a = est.vehs[i]
    y2 = a.esq[esquina_lado][2]
    it, _ = vecinos_cercanos(ys, y2)
    return separacion_dos_autos(y2, 0.0, ys[it], ls[it], est.p.L)
end

""" un paso de tiempo: todos los autos en el orden alternado. Devuelve cuántos cruzaron y = L """
function paso!(est::Estado)
    cruces = 0
    for i in est.orden
        cruces += paso_auto!(est, i)
    end
    est.t += 1
    return cruces
end


""" corre `pasos` pasos y devuelve la serie de velocidad promedio y los cruces por paso """
function simular!(est::Estado, pasos)
    V = zeros(pasos); C = zeros(Int, pasos)
    for t in 1:pasos
        C[t] = paso!(est)
        V[t] = velocidad_promedio_y(est)
    end
    return V, C
end

""" corre y guarda posición, dirección y velocidad de todos los autos en cada paso """
function simular_registro(est::Estado, pasos)
    N = length(est.vehs)
    P = zeros(pasos+1, N, 2); D = zeros(pasos+1, N, 2); V = zeros(pasos+1, N, 2)
    rec(t) = for i in 1:N
        a = est.vehs[i]
        P[t, i, 1], P[t, i, 2] = a.pos; D[t, i, 1], D[t, i, 2] = a.dir; V[t, i, 1], V[t, i, 2] = a.vel
    end
    rec(1)
    for t in 1:pasos
        paso!(est); rec(t+1)
    end
    return (P = P, D = D, V = V)
end
