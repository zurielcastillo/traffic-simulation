# Graba corridas de 2 carriles de los tres modelos (original, solo colisiones, colisiones + IDM) para
# animarlas en validacion/resultados_2_carriles_experimental.html.
# Uso: julia exporta_animacion_2c.jl <rho> <eps> <salida.json>
# Graba dos ventanas de 60 s: el arranque (0 a 60 s, todos parten detenidos) y el régimen (500 a 560 s).
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using TraficoOpt, Base64
const largo = 9/7; const d0 = 0.5; const ntot = 100
const CADA = 2       # se guarda un cuadro cada 2 pasos (0.2 s)
const CUADROS = 300  # 300 cuadros = 60 s

b64(v) = base64encode(reinterpret(UInt8, v))

""" parámetros de cada modelo, igual que en corre_n.jl """
function parametros(modelo; kw...)
    modelo == "original" && return Parametros(; kw...)
    modelo == "colisiones" && return parametros_experimentales(; modelo_aceleracion = :original, kw...)
    return parametros_experimentales(; kw...)
end

"""
graba una ventana: posición x (×1000), ángulo (×10000), velocidad en y (×1000) y posición y (×50)
de cada auto en cada cuadro. También mide la aceleración más fuerte y el frenado más fuerte de un
paso de 0.1 s a otro (en m/s²), para comparar qué tan bruscos son los modelos.
"""
function ventana!(est, L)
    buf = Int16[]; ybuf = UInt16[]; vm = Float64[]
    amax = 0.0; amin = 0.0; δt = est.p.δt
    for t in 0:(CUADROS*CADA - 1)
        if t > 0
            v0 = [a.vel[2] for a in est.vehs]
            paso!(est)
            for (i, a) in enumerate(est.vehs)
                ac = (a.vel[2] - v0[i])/δt*3.5   # u/s² → m/s²
                amax = max(amax, ac); amin = min(amin, ac)
            end
        end
        if t % CADA == 0
            for a in est.vehs
                push!(buf, round(Int16, a.pos[1]*1000), round(Int16, (atan(a.dir[2], a.dir[1]) - π/2)*10000),
                      round(Int16, clamp(a.vel[2], 0, 4)*1000))
                push!(ybuf, round(UInt16, mod(a.pos[2], L)*50))
            end
            push!(vm, round(velocidad_promedio_y(est)*3.5, digits = 2))
        end
    end
    return "{a:\"$(b64(buf))\",y:\"$(b64(ybuf))\",vm:$vm,amax:$(round(amax, digits = 1)),amin:$(round(amin, digits = 1))}"
end

ρ = eval(Meta.parse(ARGS[1])); ε = parse(Float64, ARGS[2]); salida = ARGS[3]
L = ntot*(largo + d0)/(2ρ)
mx = floor(Int, L/(largo + d0)); n1 = min(mx, ntot); n2 = ntot - n1   # se llena primero el carril 1
partes = String[]
for modelo in ("original", "colisiones", "experimental")
    est = crear_estado(parametros(modelo; L = L, egoismo = ε), [n1, n2], [d0, d0])
    arranque = ventana!(est, L)                          # 0 a 60 s
    for _ in 1:(5000 - CUADROS*CADA); paso!(est); end    # avanza hasta t = 500 s
    regimen = ventana!(est, L)                           # 500 a 560 s
    push!(partes, "$modelo:{arranque:$arranque,regimen:$regimen}")
    println(modelo, " listo")
end
write(salida, "{N:$ntot,L:$L,rho:$(round(ρ, digits = 2)),eps:$ε,$(join(partes, ","))}")
