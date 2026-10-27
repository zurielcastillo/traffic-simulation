# ---------------------------------------------------------------------------
# Seguimiento de vehículos: distancia segura y velocidad segura
# (mismas fórmulas y mismo orden de operaciones que funciones_principales.jl)
# ---------------------------------------------------------------------------

""" distancia segura entre carros """
Δx_s(d_0, α, μ, g, T_reac, v, colchon) = d_0 + (α*v^2)/(2*g*μ) + T_reac*v + colchon

""" velocidad máxima segura dada la velocidad del de enfrente v_0, la propia v_1 y la separación """
function v_i(δt, d_0, α, μ, g, T_reac, v_0, v_1, separacion, colchon, acel)
    c = -(v_0 - v_1)*δt - separacion - (1/2)*acel*(δt^2) + d_0 - colchon
    a = α/(2*μ*g)
    b = T_reac
    if b^2 - 4*a*c >= 0
        return (-b + sqrt(b^2 - 4*a*c))/(2*a)
    else
        return 0.0
    end
end

""" aceleración necesaria para quedar a la distancia segura con velocidad v_obj """
aceleracion(δt, d_0, α, μ, g, T_reac, v_0, v_1, separacion, colchon, v_obj) =
    (2/(δt^2))*((v_0 - v_1)*δt + separacion - Δx_s(d_0, α, μ, g, T_reac, v_obj, colchon))

"""
separación entre dos autos del mismo carril (el 2 es el de enfrente), con frontera periódica.
`mismo = true` cuando es el mismo auto (sólo hay un auto en el carril).

`con_signo = false` reproduce el original, que devuelve abs(sep). Con `con_signo = true` la
separación es negativa cuando los autos ya se enciman (ver `Parametros.separacion_con_signo`).
Para que el signo tenga sentido el auto 2 debe estar adelante del 1 en el orden del carril; eso
queda garantizado si los líderes se eligen por fantasma (`lider_por_fantasma = true`).
"""
function separacion_dos_autos(y1, l1, y2, l2, L; mismo = false, con_signo = false)
    mismo && return abs(L - l1)
    # y1 > y2: el de enfrente ya dio la vuelta (frontera periódica), se suma el tramo hasta L
    sep = y1 > y2 ? L - (y1 + l1/2) + (y2 - l2/2) : (y2 - l2/2) - (y1 + l1/2)
    return con_signo ? sep : abs(sep)
end

# ---------------------------------------------------------------------------
# Intelligent Driver Model (IDM): aceleración acotada y continua
# ---------------------------------------------------------------------------

"""
aceleracion_idm(p, s0, v, v_lider, s, libre)

Aceleración del IDM para un auto con velocidad `v`, cuyo líder va a `v_lider` y está a una
separación (hueco de defensa a defensa) `s`. `s0` es la separación mínima en reposo.
`libre = true` cuando no hay nadie enfrente (único auto en el carril).

    a = a_max * [ 1 - (v/v_max)^δ - (s*/s)^2 ],   s* = s0 + v T + v Δv / (2 √(a_max b))

* el término (v/v_max)^δ hace que el auto acelere suave hasta v_max en camino libre,
* el término (s*/s)^2 lo hace frenar si el hueco es menor que el deseado s*, que crece con la
  velocidad (v T, tiempo de reacción) y con lo rápido que se acerca al de enfrente (Δv = v - v_lider).

El resultado se acota entre -b_max (frenado de emergencia) y a_max. Si el hueco ya es negativo
(autos encimados) se aplica el frenado de emergencia.
"""
function aceleracion_idm(p::Parametros, s0, v, v_lider, s, libre)
    (; v_max, T_reac, idm_a, idm_b, idm_b_max, idm_δ) = p
    v = max(v, 0.0)
    termino_libre = (v/v_max)^idm_δ
    if libre
        a = idm_a*(1 - termino_libre)
    elseif s <= 0
        a = -idm_b_max
    else
        Δv = v - v_lider
        # el max(0, ·) evita que s* quede menor que s0 cuando el de enfrente se aleja rápido
        s_deseada = s0 + max(0.0, v*T_reac + v*Δv/(2*sqrt(idm_a*idm_b)))
        a = idm_a*(1 - termino_libre - (s_deseada/s)^2)
    end
    return clamp(a, -idm_b_max, idm_a)
end

"""
velocidad del siguiente paso con el IDM (actualización balística v + a δt, sin velocidades
negativas: un auto frenando se detiene, no se echa en reversa).
La separación mínima en reposo del IDM es d_0 + colchon, la misma que usa la distancia segura
del modelo original con v = 0.
"""
function velocidad_idm(p::Parametros, d_0, v_1, v_lider, sep, libre)
    a = aceleracion_idm(p, d_0 + p.colchon, v_1, v_lider, sep, libre)
    return max(0.0, v_1 + a*p.δt)
end

"""
velocidad nueva de un fantasma (velocidad propia v_1, separación sep) detrás de un
líder con velocidad v_lider. Reproduce `actualiza_velocidad_f` del original, incluido
el caso en que el fantasma es su propio líder (único auto en el carril).
"""
function velocidad_fantasma(p::Parametros, d_0, v_1, l_1, v_lider, sep, mismo)
    # modelo experimental: aceleración IDM (si está solo en el carril, camino libre)
    p.modelo_aceleracion === :idm && return velocidad_idm(p, d_0, v_1, v_lider, sep, mismo)
    # con separación con signo, un auto ya encimado con el de enfrente se detiene
    p.separacion_con_signo && !mismo && sep < 0 && return 0.0
    (; δt, α, μ, g, T_reac, colchon, acel, v_max, v_min) = p
    if mismo && (((v_1 + l_1/2) > v_1 > (v_1 - l_1/2)))
        v_lider = 0.0
    end
    v = v_i(δt, d_0, α, μ, g, T_reac, v_lider, v_1, sep, colchon, acel)
    vl = mismo ? v : v_lider
    if v > v_max
        a = aceleracion(δt, d_0, α, μ, g, T_reac, vl, v_1, sep, colchon, v_max)
        a = a > p.a_realista_max ? p.a_realista_max : (a < p.a_realista_min ? p.a_realista_min : a)
        v = v_i(δt, d_0, α, μ, g, T_reac, vl, v_1, sep, colchon, a)
        if v > v_max
            v = v_max
        end
    elseif v < 0
        a = aceleracion(δt, d_0, α, μ, g, T_reac, vl, v_1, sep, colchon, v_min)
        a = a > p.a_realista_max ? p.a_realista_max : (a < p.a_realista_min ? p.a_realista_min : a)
        v = v_i(δt, d_0, α, μ, g, T_reac, vl, v_1, sep, colchon, a)
    end
    return v
end

"""
Velocidad nueva del auto j en la predicción de un carril (`avance_un_carril` del original):
aquí NO se acota la aceleración.
"""
function velocidad_prediccion(p::Parametros, d_0, v_1, v_lider, sep, solo)
    # la predicción usa la misma regla de aceleración que la dinámica real, para que el auto que
    # decide cambiar de carril "imagine" a sus nuevos vecinos moviéndose como de verdad se mueven
    p.modelo_aceleracion === :idm && return velocidad_idm(p, d_0, v_1, v_lider, sep, solo)
    p.separacion_con_signo && !solo && sep < 0 && return 0.0
    (; δt, α, μ, g, T_reac, colchon, acel, v_max, v_min) = p
    v = v_i(δt, d_0, α, μ, g, T_reac, v_lider, v_1, sep, colchon, acel)
    vl = solo ? v : v_lider   # con un solo auto en el carril, su líder es él mismo ya actualizado
    if v > v_max
        a = aceleracion(δt, d_0, α, μ, g, T_reac, vl, v_1, sep, colchon, v_max)
        v = v_i(δt, d_0, α, μ, g, T_reac, vl, v_1, sep, colchon, a)
        if v > v_max
            v = v_max
        end
    elseif v < 0
        a = aceleracion(δt, d_0, α, μ, g, T_reac, vl, v_1, sep, colchon, v_min)
        v = v_i(δt, d_0, α, μ, g, T_reac, vl, v_1, sep, colchon, a)
    end
    return v
end
