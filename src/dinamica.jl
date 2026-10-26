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
"""
function separacion_dos_autos(y1, l1, y2, l2, L; mismo = false)
    mismo && return abs(L - l1)
    sep = y1 > y2 ? L - (y1 + l1/2) + (y2 - l2/2) : (y2 - l2/2) - (y1 + l1/2)
    return abs(sep)
end

"""
velocidad nueva de un fantasma (velocidad propia v_1, separación sep) detrás de un
líder con velocidad v_lider. Reproduce `actualiza_velocidad_f` del original, incluido
el caso en que el fantasma es su propio líder (único auto en el carril).
"""
function velocidad_fantasma(p::Parametros, d_0, v_1, l_1, v_lider, sep, mismo)
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
