# ---------------------------------------------------------------------------
# Autos fantasma, líderes y decisión de cambio de carril (n carriles)
# ---------------------------------------------------------------------------

""" el auto k cuenta en el carril ℓ: si gira, en su carril origen y destino; si no, en los que toca """
@inline function miembro(est::Estado, k, ℓ)
    est.giro[k] ? (ℓ == est.origen[k] || ℓ == destino_efectivo(est, k)) :
                  (est.carril_lo[k] <= ℓ <= est.carril_hi[k])
end

"""
carril destino de un auto que gira. Con 2 carriles un auto que gira siempre va al otro
carril (como en el original), así que si no tiene destino asignado se toma el vecino.
"""
function destino_efectivo(est::Estado, k)
    d = est.destino[k]; o = est.origen[k]
    d != o && return d
    est.nc == 1 && return o
    if o == est.nc
        return o - 1
    elseif o == 1
        return o + 1
    else
        return est.vehs[k].dir[1] >= 0 ? o + 1 : o - 1
    end
end

""" índice (1 o 2) del fantasma del auto k en el carril ℓ, o 0 """
@inline ranura(est::Estado, k, ℓ) = est.f_carril[1, k] == ℓ ? 1 : (est.f_carril[2, k] == ℓ ? 2 : 0)

""" recalcula carriles que toca y fantasmas del auto k (solo cuando k se movió) """
function actualiza_cache!(est::Estado, k)
    p = est.p; a = est.vehs[k]
    lo, hi = carriles_que_toca(p, est.nc, a)
    est.carril_lo[k] = lo; est.carril_hi[k] = hi
    vy = a.vel[2]
    if lo == hi
        ymin, ymax = intervalo_en_carril(p, est.nc, a, lo, lo, hi)
        est.f_carril[1, k] = lo; est.f_y[1, k] = (ymax + ymin)/2; est.f_largo[1, k] = ymax - ymin; est.f_vy[1, k] = vy
        # fantasma de largo cero en el carril vecino relevante (como `carros_largo_cero`)
        if est.giro[k]
            o = lo == est.origen[k] ? destino_efectivo(est, k) : est.origen[k]
        else
            o = lo < est.nc ? lo + 1 : lo - 1
        end
        esq = o > lo ? a.esq[2] : a.esq[1]
        est.f_carril[2, k] = o; est.f_y[2, k] = esq[2]; est.f_largo[2, k] = 0.0; est.f_vy[2, k] = vy
    else
        hi == lo + 1 || error("el auto $k toca más de dos carriles")
        for (s, ℓ) in ((1, lo), (2, hi))
            ymin, ymax = intervalo_en_carril(p, est.nc, a, ℓ, lo, hi)
            est.f_carril[s, k] = ℓ; est.f_y[s, k] = (ymax + ymin)/2; est.f_largo[s, k] = ymax - ymin; est.f_vy[s, k] = vy
        end
    end
end

"""
índice del auto de enfrente de i en el carril ℓ (0 si i no está en ese carril).
Igual que ordenar los autos del carril de mayor a menor y tomar el anterior (con vuelta).
"""
function lider(est::Estado, i, ℓ)
    miembro(est, i, ℓ) || return 0
    vehs = est.vehs
    pf = est.p.lider_por_fantasma
    yi = pf ? -est.f_y[ranura(est, i, ℓ), i] : -vehs[i].pos[2]
    mejor = 0; ym = 0.0      # mayor clave menor que la de i
    ultimo = i; yu = yi      # mayor clave de todas
    for k in eachindex(vehs)
        (k == i || !miembro(est, k, ℓ)) && continue
        yk = pf ? -est.f_y[ranura(est, k, ℓ), k] : -vehs[k].pos[2]
        if isless(yk, yi) || (isequal(yk, yi) && k < i)
            if mejor == 0 || isless(ym, yk) || (isequal(ym, yk) && k > mejor)
                mejor = k; ym = yk
            end
        end
        if isless(yu, yk) || (isequal(yu, yk) && k > ultimo)
            ultimo = k; yu = yk
        end
    end
    return mejor == 0 ? ultimo : mejor
end

""" llena los buffers con los fantasmas del carril ℓ en orden de índice (como `listas_pregiro!`) """
function lista_carril!(idx, ys, ls, vs, est::Estado, ℓ)
    empty!(idx); empty!(ys); empty!(ls); empty!(vs)
    for k in eachindex(est.vehs)
        if miembro(est, k, ℓ)
            s = ranura(est, k, ℓ)
            push!(idx, k); push!(ys, est.f_y[s, k]); push!(ls, est.f_largo[s, k]); push!(vs, est.f_vy[s, k])
        end
    end
    return length(idx)
end

"""
valores mayor y menor más cercanos a `el` dentro de ys (con vuelta, como `numeros_cercanos`),
devueltos como la primera posición en que aparecen.
"""
function vecinos_cercanos(ys, el)
    mayor = Inf; menor = -Inf
    for y in ys
        if y > el && y < mayor; mayor = y; end
        if y < el && y > menor; menor = y; end
    end
    a = mayor == Inf ? minimum(ys) : mayor
    b = menor == -Inf ? maximum(ys) : menor
    return findfirst(==(a), ys), findfirst(==(b), ys)
end

"""
predicción de un paso del carril destino (`avance_un_carril` sobre una copia).
Se hace en O(M): el auto j solo depende del j+1 ya actualizado (o del 1 para el último).
"""
function prediccion_carril!(ys, vs, ls, p::Parametros, d_0, nsteps)
    M = length(ys); L = p.L; δt = p.δt
    l = ls[1]
    for _ in 1:nsteps
        for idx in 1:M
            j = M - idx + 1
            jn = j < M ? j + 1 : 1
            Yn = ys[jn]; Yj = ys[j]
            sep = Yn > Yj ? Yn - Yj - l : (Yn < Yj ? L - (Yj - Yn + l) : 0.0)
            v = velocidad_prediccion(p, d_0, vs[j], vs[jn], sep, M == 1)
            vs[j] = v
            y = Yj + v*δt
            ys[j] = y > L ? y - L : y
        end
    end
end

"""
condiciones de los tres autos relevantes (`condiciones_tres_car`): true si el auto quedaría
encimado con el de enfrente (i) o el de atrás (j) en el carril destino
"""
function condiciones_tres_car(a, b, yc1, li, lj, L)
    if b < yc1 < a
        return a - li/2 <= yc1 <= a || b <= yc1 <= b + lj/2
    elseif a < b < yc1
        return L - li/2 <= yc1 - a <= L || b <= yc1 <= b + lj/2
    elseif yc1 < a < b
        return a - li/2 <= yc1 <= a || -L <= yc1 - b <= -L + lj/2
    else
        return true
    end
end

envolver(yc, L) = yc > L ? yc - floor(yc/L)*L : yc

"""
predicción, distancia segura y egoísmo hacia el carril destino tgt (`decide_cambiar_derecha/izquierda`).
`esquina` = 2 si el destino está a la derecha (x mayor), 1 si está a la izquierda.
"""
function decide_cambiar(est::Estado, i, tgt, esquina)
    p = est.p; a = est.vehs[i]; L = p.L
    a.vel[2] <= p.v_min && return false
    b = copia(a)
    velocidad_angular_carro_correcion!(b, 1*p.δt, 0)
    yc = b.esq[esquina][2]; tc = 1*p.δt
    idx, ys, ls, vs = est.buf_idx, est.buf_y, est.buf_l, est.buf_v
    lista_carril!(idx, ys, ls, vs, est, tgt)
    ii, jj = vecinos_cercanos(ys, a.esq[esquina][2])
    d_0 = p.d_0[tgt]
    prediccion_carril!(ys, vs, ls, p, d_0, length(1:(tc/p.δt)))
    # 1) que no quede encimado con los vecinos
    yc1 = envolver(yc, L)
    condiciones_tres_car(ys[ii], ys[jj], yc1, ls[ii], ls[jj], L) && return false
    # 2) distancia segura con el nuevo auto de enfrente
    d_segura = Δx_s(d_0, p.α, p.μ, p.g, p.T_reac, a.vel[2], p.colchon_distancia_segura)
    # (con separación con signo, si la esquina ya quedaría metida en el de enfrente d_auto < 0 y se rechaza)
    cs = p.separacion_con_signo
    d_auto = separacion_dos_autos(yc1, 0.0, ys[ii], ls[ii], L; con_signo = cs)
    d_segura > d_auto && return false
    # 3) egoísmo: no frenar demasiado al nuevo auto de atrás
    d_j = separacion_dos_autos(ys[jj], ls[jj], yc1, 0.0, L; con_signo = cs)
    # si el nuevo auto de atrás ya quedaría encimado con nosotros, no hay egoísmo que valga
    cs && d_j < 0 && return false
    v_0 = vs[jj]
    # Nota: con aceleración IDM este criterio se deja igual (velocidad SEGURA que necesitaría el de
    # atrás según la fórmula de la tesis). Así ε conserva su significado: la fracción de velocidad que
    # el auto está dispuesto a quitarle al de atrás.
    v = v_i(p.δt, d_0, p.α, p.μ, p.g, p.T_reac, v_0, a.vel[2], d_j, p.colchon, p.acel)
    1 - p.egoismo > v/v_0 && return false
    return true
end

""" corrige el ángulo de giro para no salirse del carril (frontera xb, centro destino c) """
function correccion_angulo!(a::Vehiculo, θ, xb, c, p::Parametros)
    if abs(a.pos[1] - c) < p.error_giro
        rotacion_carro_recto!(angulo_mas_corto_hacia_arriba(a.dir), a)
        return 0.0
    end
    frente_x = (a.esq[1] + a.esq[2])[1]/2
    if xb - frente_x > 0
        θ = -abs(θ)
    elseif xb - frente_x < 0
        θ = abs(θ)
    end
    return θ
end

frontera(p::Parametros, o, t) = fin_carril(p, min(o, t))
centro_destino(p::Parametros, o, t) = t > o ? frontera(p, o, t) + p.ancho_carril/2 : frontera(p, o, t) - p.ancho_carril/2

"""
condiciones generales para permitir el cambio entre los carriles a ambos lados de la frontera
(`decide_cambiar_general`). θ1 < 0: hacia x mayor; θ1 > 0: hacia x menor.
"""
function decide_cambiar_general(est::Estado, i, θ1, o, t)
    p = est.p; a = est.vehs[i]; L = p.L
    izq, der = min(o, t), max(o, t)
    if θ1 < 0
        cur, tgt, esquina = izq, der, 2
    elseif θ1 > 0
        cur, tgt, esquina = der, izq, 1
    else
        return false   # el original lanza UndefVarError en este caso
    end
    k = lider(est, i, cur)
    k != 0 && est.giro[k] && return false
    idx, ys, ls, vs = est.buf_idx, est.buf_y, est.buf_l, est.buf_v
    # separación con el de enfrente en el carril actual (el auto contra los fantasmas)
    lista_carril!(idx, ys, ls, vs, est, cur)
    ic, _ = vecinos_cercanos(ys, a.pos[2])
    cs = p.separacion_con_signo
    sep_cur = separacion_dos_autos(a.pos[2], a.largo, ys[ic], ls[ic], L; con_signo = cs)
    vprom_cur = sum(vs)/length(vs)
    M = lista_carril!(idx, ys, ls, vs, est, tgt)
    if M > 0
        y2 = a.esq[esquina][2]
        it, _ = vecinos_cercanos(ys, y2)
        # corrección experimental: si el auto de enfrente en el carril destino está a medio cambio
        # de carril (entrando o saliendo), no se empieza el cambio. Es el patrón que origina los
        # choques graves con 3 y 4 carriles: dos autos cambiando juntos y el de enfrente se detiene.
        p.no_cambiar_tras_auto_girando && est.giro[idx[it]] && return false
        sep_t = separacion_dos_autos(y2, 0.0, ys[it], ls[it], L; con_signo = cs)
        vprom_t = sum(vs)/M
    else
        sep_t = Inf; vprom_t = p.v_max
    end
    # incentivo de velocidad (desactivado en el original)
    p.incentivo_velocidad && a.vel[2] > vprom_t && return false
    sep_cur > sep_t && return false
    M == 0 && return true
    return decide_cambiar(est, i, tgt, esquina)
end
