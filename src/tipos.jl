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

    # -----------------------------------------------------------------------------------------------
    # Cambios experimentales (rama experimental_colisiones_idm). Todos vienen APAGADOS por defecto,
    # así que con los valores por defecto el modelo sigue siendo idéntico al original. Para prenderlos
    # todos de una vez usar `parametros_experimentales(...)` (definida abajo).
    # -----------------------------------------------------------------------------------------------

    # Colisiones 1: en el original `separacion_dos_autos` devuelve abs(sep). Si dos autos ya se enciman
    # la separación real es negativa, pero la regla de velocidad recibe un número positivo y el auto de
    # atrás NO frena: sigue metiéndose en el de enfrente. Con esta opción la separación conserva su signo
    # y un auto encimado se detiene (y no se le permite cambiar de carril hacia un hueco negativo).
    separacion_con_signo::Bool = false

    # Colisiones 2: en 3 y 4 carriles los choques graves empiezan cuando dos autos seguidos cambian de
    # carril juntos y el de enfrente se detiene a medio cambio. El original ya prohíbe empezar un cambio
    # si el auto de enfrente en el carril ACTUAL está girando; esta opción también lo prohíbe si el auto
    # de enfrente en el carril DESTINO está girando (va entrando o saliendo de ese carril).
    no_cambiar_tras_auto_girando::Bool = false

    # Aceleración: `:original` usa la velocidad segura de la tesis (el auto puede pasar de v_max a 0 en
    # un solo paso de 0.1 s). `:idm` usa el Intelligent Driver Model (Treiber, Hennecke y Helbing, 2000),
    # con aceleración y frenado acotados. Unidades del modelo: 1 unidad de distancia = 3.5 m y el tiempo
    # en segundos, así que 1 unidad/s² = 3.5 m/s².
    modelo_aceleracion::Symbol = :original
    idm_a::Float64 = 0.3       # aceleración máxima cómoda: 0.3 u/s² ≈ 1.05 m/s² (auto de calle típico)
    idm_b::Float64 = 0.6       # frenado cómodo: 0.6 u/s² ≈ 2.1 m/s²
    idm_b_max::Float64 = 2.5   # frenado de emergencia (tope físico): 2.5 u/s² ≈ 8.75 m/s² (≈ 0.9 g)
    idm_δ::Float64 = 4.0       # exponente de aceleración del IDM (valor estándar de la literatura)
    # separación mínima en reposo del IDM: 0.3 u ≈ 1.05 m. Debe ser MENOR que la separación inicial de
    # los autos (d_0 = 0.5): si fuera mayor, un carril lleno arrancaría con todos los huecos por debajo
    # del mínimo y nadie se movería nunca (el IDM solo acelera si el hueco es mayor que s0).
    idm_s0::Float64 = 0.3

    # Tiempo de reacción para notar un cambio de carril (solo con `no_cambiar_tras_auto_girando`).
    # Con 0 el auto de atrás se entera al instante de que el de enfrente decidió cambiar. Con t > 0
    # solo lo nota cuando el otro ya lleva t segundos cambiando, como un conductor que tarda en ver
    # la direccional y el movimiento del auto de enfrente. Durante ese tiempo puede empezar su propio
    # cambio, así que se vuelven posibles los cambios "en cadena" pero espaciados, no todos en el mismo
    # paso como en el original. El valor natural es el tiempo de reacción del modelo, T_reac = 1 s.
    t_aviso_giro::Float64 = 0.0

    # Filtros para que los cambios de carril sean realistas. Se revisan ANTES de la regla de
    # egoísmo ε, que se queda igual: un auto solo evalúa cambiarse (y luego aplica ε) si pasa
    # los tres filtros. Con los valores por defecto ningún filtro actúa.
    #
    # 1) Necesidad: el auto solo considera cambiarse si va más lento que `fraccion_necesidad * v_max`.
    #    `Inf` apaga el filtro. Un valor típico es 0.95: quien ya va libre a su velocidad deseada no
    #    tiene motivo para cambiarse (en el original, a baja densidad, se cambiaban sin parar).
    fraccion_necesidad::Float64 = Inf
    # 2) Umbral de ganancia (histéresis): el hueco enfrente en el carril destino debe ser mayor que el
    #    del carril actual por AL MENOS esta distancia (en unidades; un auto mide 9/7 ≈ 1.29 u).
    #    En el original basta con que sea mayor, aunque sea por un milímetro.
    umbral_ganancia::Float64 = 0.0
    # 3) Tiempo mínimo (en segundos) entre el final de un cambio de carril y el inicio del siguiente
    #    del mismo auto. Evita el ir y venir entre carriles.
    tiempo_entre_cambios::Float64 = 0.0

    # Colisiones 3: un auto que se cambia de carril deja de contar en su carril de origen en cuanto ya
    # no lo toca. Ver `miembro` en cambio_de_carril.jl (con 3 carriles su fantasma de largo cero podía
    # quedar encima de un auto detenido y "taparlo" para el de atrás).
    fantasma_solo_si_ocupa::Bool = false
    # Colisiones 4: al calcular la velocidad segura, el auto también mira al auto de enfrente de su
    # líder y frena por el más cercano. Cubre el caso inverso: el fantasma de largo cero de un auto que
    # ENTRA al carril queda encima de otro auto del carril destino y lo tapa para el de atrás.
    mirar_dos_adelante::Bool = false
end

numero_carriles(p::Parametros) = length(p.d_0)

"""
parametros_experimentales(; kw...)
Parámetros con TODAS las correcciones experimentales prendidas (separación con signo, no cambiar
detrás de un auto que gira, líder por fantasma, velocidad no negativa y aceleración IDM).
Cualquier otro parámetro se pasa igual que a `Parametros`, por ejemplo
`parametros_experimentales(L = 50.0, d_0 = fill(0.5, 3), egoismo = 0.47)`.
"""
function parametros_experimentales(; kw...)
    base = (separacion_con_signo = true, no_cambiar_tras_auto_girando = true, lider_por_fantasma = true,
            velocidad_no_negativa = true, modelo_aceleracion = :idm)
    # `merge` deja que lo que pase el usuario (kw) reemplace a los valores de `base`,
    # por ejemplo para apagar solo una de las correcciones
    return Parametros(; merge(base, values(kw))...)
end

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
    # paso en que cada auto decidió su último cambio de carril (para `t_aviso_giro`);
    # vale typemin(Int) si nunca ha decidido uno
    t_decision::Vector{Int}
    # paso en que cada auto terminó su último cambio de carril (para `tiempo_entre_cambios`);
    # vale typemin(Int) si nunca ha terminado uno
    t_fin_cambio::Vector{Int}
    # buffers reutilizables para la predicción del carril destino
    buf_idx::Vector{Int}
    buf_y::Vector{Float64}
    buf_l::Vector{Float64}
    buf_v::Vector{Float64}
end
