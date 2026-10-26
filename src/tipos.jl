const V2 = SVector{2,Float64}

"""
Parámetros del modelo. Los valores por defecto son los del README original.
`d_0` es un vector con la separación mínima de cada carril (su largo define cuántos carriles hay).
"""
Base.@kwdef struct Parametros
    δt::Float64 = 0.1
    d_0::Vector{Float64} = [0.5, 0.5]
    α::Float64 = 0.8
    μ::Float64 = 0.8
    g::Float64 = 2.803
    T_reac::Float64 = 1.0
    colchon::Float64 = 0.21
    acel::Float64 = 1.0
    v_max::Float64 = 4.0
    v_min::Float64 = 0.001
    L::Float64 = 110.0
    egoismo::Float64 = 0.8
    ancho_carril::Float64 = 1.0
    a_realista_max::Float64 = 4.0
    a_realista_min::Float64 = -10.0
    error_giro::Float64 = 1e-2   # tolerancia para enderezar el auto al llegar al centro del carril
    err_dir::Float64 = 1e-6      # tolerancia para decidir si el auto está girando
    colchon_distancia_segura::Float64 = 0.2  # el original usa el valor por defecto 0.2 en `distancia_segura`
    incentivo_velocidad::Bool = false        # en el original `velocidades_test_*` siempre devuelve false
    # Corrección opcional (desactivada = igual al original): en el original, si la velocidad segura sale
    # negativa (no alcanza a frenar), el auto avanza con la NORMA de esa velocidad, es decir, hacia adelante.
    velocidad_no_negativa::Bool = false
    # Corrección opcional: en el original el auto de enfrente se elige por la posición del CENTRO del auto,
    # pero la separación se mide con el fantasma. Un auto que está saliendo del carril tiene un fantasma de
    # largo cero en su esquina delantera y puede "tapar" al verdadero auto de enfrente. Con esta opción
    # el orden dentro del carril se hace con la posición del fantasma en ese carril.
    lider_por_fantasma::Bool = false
end

numero_carriles(p::Parametros) = length(p.d_0)

""" Un auto: rectángulo con posición (centro), 4 esquinas, velocidad y dirección """
mutable struct Vehiculo
    ancho::Float64
    largo::Float64
    pos::V2
    esq::NTuple{4,V2}
    vel::V2
    dir::V2
    indice::Int
end

esquinas_rectas(x, y, a, l) = (V2(x - a/2, y + l/2), V2(x + a/2, y + l/2), V2(x + a/2, y - l/2), V2(x - a/2, y - l/2))

Vehiculo(ancho, largo, x, y, indice) =
    Vehiculo(ancho, largo, V2(x, y), esquinas_rectas(x, y, ancho, largo), V2(0, 0), V2(0, 1), indice)

"""
Estado completo de la simulación.
Los arreglos `carril_lo/carril_hi` y `f_*` son cachés: describen los carriles que toca cada
auto y sus autos fantasma, y solo se recalculan para el auto que se acaba de mover.
"""
mutable struct Estado
    p::Parametros
    nc::Int
    vehs::Vector{Vehiculo}
    giro::Vector{Bool}
    θ::Vector{Float64}
    origen::Vector{Int}
    destino::Vector{Int}
    orden::Vector{Int}
    carril_lo::Vector{Int}
    carril_hi::Vector{Int}
    f_carril::Matrix{Int}      # (2, N) carril de cada uno de los 2 fantasmas
    f_y::Matrix{Float64}
    f_largo::Matrix{Float64}
    f_vy::Matrix{Float64}
    t::Int
    # buffers reutilizables para la predicción del carril destino
    buf_idx::Vector{Int}
    buf_y::Vector{Float64}
    buf_l::Vector{Float64}
    buf_v::Vector{Float64}
end
