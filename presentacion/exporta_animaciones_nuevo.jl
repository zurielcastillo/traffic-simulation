# Animaciones de dos carriles para presentacion_modelo_nuevo.html, con el modelo nuevo:
# correcciones de colisiones + 1 s de reacción para notar cambios de carril + filtros de cambio realista.
# Mismo formato que exporta_animaciones.jl (x*1000, ángulo*10000, vy*1000 en Int16; y*50 en UInt16).
# Uso: julia exporta_animaciones_nuevo.jl heroe|duelo0|duelo9
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src")); using TraficoOpt, Base64, Random
const largo = 9/7; const d0 = 0.5; const ntot = 100
b64(v) = base64encode(reinterpret(UInt8, v))
const CADA = 2; const FR = 600

""" parámetros del modelo nuevo (el mismo que `filtros_reac` en validacion/n_carriles/corre_n.jl) """
modelo_nuevo(; kw...) = parametros_experimentales(; modelo_aceleracion = :original, t_aviso_giro = 1.0,
                                                   fraccion_necesidad = 0.95, umbral_ganancia = largo,
                                                   tiempo_entre_cambios = 5.0, fantasma_solo_si_ocupa = true, mirar_dos_adelante = true, kw...)

function distrib(L)
    e = largo + d0; mx = floor(Int, L/e)
    ntot <= mx && return ntot, 0
    ntot <= 2mx && return mx, ntot - mx
    return mx, mx
end

function dos(ρ, ε; t0 = 5000, uniforme = false, pert = 0.0, semilla = 1)
    L = ntot*(largo + d0)/(2ρ); n1, n2 = uniforme ? (ntot ÷ 2, ntot - ntot ÷ 2) : distrib(L)
    sep = uniforme ? L/n1 - largo : d0
    est = crear_estado(modelo_nuevo(L = L, egoismo = ε), [n1, n2], [sep, sep])
    if uniforme && pert > 0   # perturbación: corre cada auto un poco hacia adelante o atrás
        rng = MersenneTwister(semilla)
        for k in eachindex(est.vehs)
            a = est.vehs[k]
            est.vehs[k] = TraficoOpt.Vehiculo(a.ancho, a.largo, a.pos[1], a.pos[2] + pert*sep*(2rand(rng) - 1), k)
        end
        for k in eachindex(est.vehs); TraficoOpt.actualiza_cache!(est, k); end
    end
    for _ in 1:t0; paso!(est); end
    buf = Int16[]; ybuf = UInt16[]; vm = Float64[]; camb = Int[]; o = copy(est.origen); nch = 0
    for t in 0:(FR*CADA - 1)
        if t > 0
            paso!(est)
            for i in eachindex(o); est.origen[i] != o[i] && (nch += 1); end
            o .= est.origen
        end
        if t % CADA == 0
            for a in est.vehs
                push!(buf, round(Int16, a.pos[1]*1000), round(Int16, (atan(a.dir[2], a.dir[1]) - π/2)*10000), round(Int16, clamp(a.vel[2], 0, 4)*1000))
                push!(ybuf, round(UInt16, mod(a.pos[2], L)*50))
            end
            push!(vm, round(velocidad_promedio_y(est)*3.5, digits = 2)); push!(camb, nch)
        end
    end
    println("dos ρ=$ρ ε=$ε cambios=$nch vm=$(round(sum(vm)/length(vm), digits=2)) choques al final=$(length(choques(est)))")
    "{N:$(length(est.vehs)),L:$L,rho:$ρ,eps:$ε,a:\"$(b64(buf))\",y:\"$(b64(ybuf))\",vm:$vm,camb:$camb}"
end

caso = ARGS[1]
# héroe: egoístas en ρ = 0.47 desde el arranque (todos en el carril 1, detenidos), así se ven los
# primeros cambios de carril hacia el carril vacío
s = caso == "heroe" ? dos(0.47, 0.89; t0 = 0) :
    caso == "duelo0" ? dos(0.47, 0.0) : dos(0.47, 0.89)
write("$caso.js", s)
