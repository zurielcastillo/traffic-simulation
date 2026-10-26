# ---------------------------------------------------------------------------
# Geometría y cinemática (mismas operaciones aritméticas que la versión original)
# ---------------------------------------------------------------------------

"""
rotación de x por la matriz [c -s; s c]. Se escribe con `fma` para dar exactamente el mismo
redondeo que el producto matriz-vector (BLAS) que usa la versión original.
"""
@inline rota(c, s, x::V2) = V2(fma(-s, x[2], c*x[1]), fma(c, x[2], s*x[1]))

""" norma euclidiana igual a `LinearAlgebra.norm` para vectores de 2 entradas """
@inline function norma(v::V2)
    m = max(abs(v[1]), abs(v[2]))
    (iszero(m) || isinf(m)) && return m
    return sqrt(abs2(v[1]) + abs2(v[2]))
end

""" rota el auto un ángulo θ alrededor de su centro (esquinas y dirección) """
function rotacion_carro!(θ, a::Vehiculo)
    c, s = cos(θ), sin(θ)
    e = a.esq
    a.esq = ntuple(i -> rota(c, s, e[i] - a.pos) + a.pos, 4)
    a.dir = rota(c, s, a.dir)
    return a
end

""" igual que `rotacion_carro_recto!` del original: el signo depende de la dirección en x """
function rotacion_carro_recto!(θ, a::Vehiculo)
    if a.dir[1] < 0
        θ = -abs(θ)
    end
    rotacion_carro!(θ, a)
end

""" ángulo necesario para alcanzar la dirección [0,1] """
function angulo_mas_corto_hacia_arriba(v)
    cosθ = v[1] * 0.0 + v[2] * 1.0
    cosθ = cosθ > 1.0 ? 1.0 : (cosθ < -1.0 ? -1.0 : cosθ)
    θ = acos(cosθ)
    return θ ≤ π/2 ? θ : π - θ
end

""" actualiza la velocidad y gira el auto para que apunte en la dirección de la velocidad """
function actualiza_v!(a::Vehiculo, v::V2)
    v0 = a.dir
    a.vel = v
    nv = norma(v)
    if nv > 0
        v1 = v ./ nv
        θ1 = atan(v1[2], v1[1])
        θ0 = atan(v0[2], v0[1])
        rotacion_carro!(θ1 - θ0, a)
    end
    return a
end

"""
Avanza el auto un tiempo t con ángulo de giro θ1 (modelo de dos ejes).
Equivalente a `velocidad_angular_carro_correcion!` del original.
"""
function velocidad_angular_carro_correcion!(a::Vehiculo, t, θ1)
    θ0 = atan(a.dir[2], a.dir[1])
    θ = pi - θ1
    θ2 = θ0 - θ1
    Lc = a.largo
    e = a.esq
    back = (e[3] + e[4]) ./ 2
    front = (e[1] + e[2]) ./ 2
    v = norma(a.vel)
    x = Lc - cos(θ)*v*t - sqrt(Lc^2 - sin(θ)^2*v^2 * t^2)
    front = front + x * a.dir
    back = back + v*t*V2(cos(θ2), sin(θ2))
    dx = (front + back) ./ 2 .- a.pos
    a.pos = a.pos .+ dx
    a.esq = ntuple(i -> e[i] .+ dx, 4)
    vnew = v*(front - back) ./ Lc
    actualiza_v!(a, vnew)
    return a
end

copia(a::Vehiculo) = Vehiculo(a.ancho, a.largo, a.pos, a.esq, a.vel, a.dir, a.indice)

""" condición periódica: si el auto pasa de L regresa al inicio """
function limites_auto_carril!(a::Vehiculo, L)
    if a.pos[2] > L
        d = -L
        a.pos = V2(a.pos[1], a.pos[2] + d)
        e = a.esq
        a.esq = ntuple(i -> V2(e[i][1], e[i][2] + d), 4)
        return true
    end
    return false
end

""" máximo ángulo de giro permitido (depende de la norma de la velocidad) """
maximo_giro(a::Vehiculo) = π/4*(1/(0.5*norma(a.vel)+1))^(1/2)

# ---------------------------------------------------------------------------
# Carriles: el carril k ocupa  A(k-1) < x <= A k
# ---------------------------------------------------------------------------

inicio_carril(p::Parametros, k) = p.ancho_carril*(k-1)
fin_carril(p::Parametros, k) = p.ancho_carril*k
centro_carril(p::Parametros, k) = (inicio_carril(p, k) + fin_carril(p, k))/2

""" carril (1..nc) en el que cae una coordenada x, o 0 si no cae en ninguno """
function carril_de_x(p::Parametros, nc, x)
    for k in 1:nc
        if inicio_carril(p, k) < x <= fin_carril(p, k)
            return k
        end
    end
    return 0
end

""" carriles mínimo y máximo que tocan las esquinas del auto """
function carriles_que_toca(p::Parametros, nc, a::Vehiculo)
    lo, hi = typemax(Int), 0
    for e in a.esq
        k = carril_de_x(p, nc, e[1])
        if k > 0
            lo = min(lo, k); hi = max(hi, k)
        end
    end
    return lo, hi
end

function intersecta_recta(x1, x2, c)
    m = (x1[2] - x2[2])/(x1[1] - x2[1])
    b = x1[2] - m*x1[1]
    return m*c + b
end

""" extremos en y de la parte del auto que queda en el carril k (incluye cortes con las fronteras) """
function intervalo_en_carril(p::Parametros, nc, a::Vehiculo, k, lo, hi)
    ymin, ymax = Inf, -Inf
    e = a.esq
    for i in 1:4
        if carril_de_x(p, nc, e[i][1]) == k
            ymin = min(ymin, e[i][2]); ymax = max(ymax, e[i][2])
        end
    end
    for xb in (k > lo ? inicio_carril(p, k) : NaN, k < hi ? fin_carril(p, k) : NaN)
        isnan(xb) && continue
        for i in 1:4
            e1 = e[i]; e2 = e[mod1(i+1, 4)]
            if e1[1] <= xb <= e2[1] || e1[1] >= xb >= e2[1]
                y = intersecta_recta(e1, e2, xb)
                ymin = min(ymin, y); ymax = max(ymax, y)
            end
        end
    end
    return ymin, ymax
end
