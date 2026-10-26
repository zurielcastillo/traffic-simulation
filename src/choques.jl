# ---------------------------------------------------------------------------
# Detección de choques con el teorema del eje separador (SAT), como funcion_detecta_choque.jl,
# pero también revisa la frontera periódica (un auto cerca de y = L contra uno cerca de y = 0)
# ---------------------------------------------------------------------------

function proyectar(esq, eje)
    mn, mx = Inf, -Inf
    for e in esq
        pr = dot(e, eje); mn = min(mn, pr); mx = max(mx, pr)
    end
    return mn, mx
end

function se_superponen(e1::NTuple{4,V2}, e2::NTuple{4,V2})
    for esq in (e1, e2), i in 1:4
        ar = esq[mod1(i+1, 4)] - esq[i]
        nrm = V2(-ar[2], ar[1]); m = norma(nrm)
        m > 0 || continue
        eje = nrm / m
        a1, b1 = proyectar(e1, eje); a2, b2 = proyectar(e2, eje)
        (b1 < a2 || b2 < a1) && return false
    end
    return true
end

"""
devuelve la lista de pares (i, j) de autos que se enciman. Solo compara autos cuya distancia en y
(con vuelta periódica) es menor que la suma de sus largos, así que es casi O(N).
"""
function choques(est::Estado)
    L = est.p.L; vehs = est.vehs; N = length(vehs)
    pares = Tuple{Int,Int}[]
    for i in 1:N, j in i+1:N
        a, b = vehs[i], vehs[j]
        dy = b.pos[2] - a.pos[2]
        dy -= L*round(dy/L)
        abs(dy) > a.largo + b.largo && continue
        abs(b.pos[1] - a.pos[1]) > a.largo + b.largo && continue
        desp = V2(0.0, (b.pos[2] - a.pos[2]) - dy)   # trae a b junto a a
        eb = ntuple(k -> b.esq[k] - desp, 4)
        se_superponen(a.esq, eb) && push!(pares, (i, j))
    end
    return pares
end
