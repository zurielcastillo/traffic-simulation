# Compara la versión original y la optimizada paso a paso.
# Uso:  julia validacion/comparar.jl [pasos] [L] [n1] [n2] [sep1] [sep2] [egoismo]
# Por defecto usa la configuración del README con 300 pasos (la original tarda ~1 min).
include(joinpath(@__DIR__, "cargar_original.jl"))
include(joinpath(@__DIR__, "..", "src", "TraficoOpt.jl"))
import .TraficoOpt as TO

args = ARGS
pasos = length(args) >= 1 ? parse(Int, args[1]) : 300
L     = length(args) >= 2 ? parse(Float64, args[2]) : 110.0
n     = length(args) >= 3 ? parse(Int, args[3]) : 55
m     = length(args) >= 4 ? parse(Int, args[4]) : 45
s1    = length(args) >= 5 ? parse(Float64, args[5]) : 0.5
s2    = length(args) >= 6 ? parse(Float64, args[6]) : 1.1
ego   = length(args) >= 7 ? parse(Float64, args[7]) : 0.8

function registro_original(pasos)
    veh = carros_dos_carriles(ancho, largo, L, s1, s2, n, m; xs = 1/2)
    carriless = carriles(1,2); giro = comprobacion_giro(veh); θv = zeros(length(veh))
    orig = carril_original(veh, carros_i_carriles(veh, carriless))
    N = n + m; P = zeros(pasos+1, N, 2); D = zeros(pasos+1, N, 2); V = zeros(pasos+1, N, 2)
    rec(t) = for i in 1:N; P[t,i,:] .= veh[i].posicion; D[t,i,:] .= veh[i].direccion; V[t,i,:] .= veh[i].velocidad; end
    rec(1)
    for t in 1:pasos
        avance_dos_carriles_con_giro_sin_anim(veh,θv,carriless,orig,giro,ego,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m)
        rec(t+1)
    end
    return (P = P, D = D, V = V)
end
registro_nuevo(pasos) = TO.simular_registro(TO.crear_estado(TO.Parametros(L = L, egoismo = ego), [n, m], [s1, s2]), pasos)

registro_original(2); registro_nuevo(2)   # compilar
t0 = time(); a = registro_original(pasos); t1 = time()
b = registro_nuevo(pasos); t2 = time()
println("Original:   $(round(t1 - t0, digits = 2)) s")
println("Optimizada: $(round(t2 - t1, digits = 3)) s   ($(round((t1 - t0)/(t2 - t1), digits = 0))× más rápida)")
println("Posiciones, velocidades y direcciones idénticas en los $pasos pasos: ", a.P == b.P && a.V == b.V && a.D == b.D)
println("Diferencia máxima de posición: ", maximum(abs.(a.P .- b.P)))
cambios = count(i -> maximum(abs.(a.P[:, i, 1] .- a.P[1, i, 1])) > 0.5, 1:n+m)
println("Autos que cambiaron de carril: $cambios")
