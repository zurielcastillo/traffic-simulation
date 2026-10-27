push!(LOAD_PATH, joinpath(@__DIR__, "..", "src")); using TraficoOpt, Base64, Random
const largo = 9/7; const d0 = 0.5; const ntot = 100
function distrib(L)
    e = largo + d0; mx = floor(Int, L/e)
    ntot <= mx && return ntot, 0
    ntot <= 2mx && return mx, ntot - mx
    return mx, mx
end
b64(v) = base64encode(reinterpret(UInt8, v))
const CADA = 2; const FR = 600
# dos carriles: x*1000, y*50, ang*10000, vy*1000
function dos(ρ, ε; t0 = 5000, uniforme = false, pert = 0.0, semilla = 1)
    L = ntot*(largo + d0)/(2ρ); n1, n2 = uniforme ? (ntot ÷ 2, ntot - ntot ÷ 2) : distrib(L)
    sep = uniforme ? L/n1 - largo : d0
    est = crear_estado(Parametros(L = L, egoismo = ε), [n1, n2], [sep, sep])
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
    println("dos ρ=$ρ ε=$ε cambios=$nch vm=$(round(sum(vm)/length(vm), digits=2))")
    "{N:$(length(est.vehs)),L:$L,rho:$ρ,eps:$ε,a:\"$(b64(buf))\",y:\"$(b64(ybuf))\",vm:$vm,camb:$camb}"
end
# un carril (reglas de avance_en_un_carril, T_reac = 0.3 como en las figuras 4.2-4.4)
function uno(ρ; t0 = 3000, uniforme = false, fr = FR)
    L = ntot*(largo + d0)/ρ; p = Parametros(L = L, T_reac = 0.3)
    ys = posiciones_iniciales(ntot, largo, uniforme ? L/ntot - largo : d0); vs = zeros(ntot)
    medicion_un_carril(ys, vs, largo, p, d0, t0)
    ybuf = UInt16[]; vbuf = UInt16[]; vm = Float64[]
    for f in 1:fr
        medicion_un_carril(ys, vs, largo, p, d0, CADA)
        append!(ybuf, round.(UInt16, mod.(ys, L) .* 50)); append!(vbuf, round.(UInt16, clamp.(vs, 0, 4) .* 1000))
        push!(vm, round(sum(vs)/ntot*3.5, digits = 2))
    end
    println("uno ρ=$ρ vm=$(round(sum(vm)/fr, digits=2)) vfin=$(vs[1]) $(vs[end])")
    "{N:$ntot,L:$L,rho:$ρ,y:\"$(b64(ybuf))\",v:\"$(b64(vbuf))\",vm:$vm}"
end
caso = ARGS[1]
s = caso == "heroe" ? dos(0.4, 0.89; t0 = 0, uniforme = true, pert = parse(Float64, get(ARGS, 2, "0.45")), semilla = parse(Int, get(ARGS, 3, "2"))) :
    caso == "duelo0" ? dos(0.53, 0.0) :
    caso == "duelo9" ? dos(0.53, 0.89) :
    caso == "uno2" ? uno(0.2; uniforme = true, fr = round(Int, 48*(100*(largo + d0)/0.2/100)/4/0.2)) : caso == "uno5" ? uno(0.53) : uno(0.87)
write("$caso.js", s)
