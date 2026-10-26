# ---------------------------------------------------------------------------
# Dibujo y animación con Plots (opcional: incluir después de `using Plots`)
#   include("dibujo.jl")
#   anim = animacion!(est, 500); gif(anim, "trafico.gif", fps = 20)
# ---------------------------------------------------------------------------
using Plots

""" dibuja los autos del estado y las líneas de los carriles """
function dibujar(est::TraficoOpt.Estado; kargs...)
    p = est.p; nc = est.nc
    plt = plot(; legend = false, ylim = (0, p.L), xlim = (-1, nc*p.ancho_carril + 1), aspect_ratio = :auto, kargs...)
    for (i, a) in enumerate(est.vehs)
        xs = [e[1] for e in a.esq]; ys = [e[2] for e in a.esq]
        c = Plots.HSV((i*137.508) % 360, 0.6, 0.85)
        plot!(plt, Shape(xs, ys); color = c, linecolor = :black, linewidth = 0.5)
    end
    vline!(plt, [p.ancho_carril*k for k in 0:nc]; color = :black)
    return plt
end

""" avanza `pasos` pasos y regresa una animación con un cuadro cada `cada` pasos (como `avance_carros_general!`) """
function animacion!(est::TraficoOpt.Estado, pasos; cada = 1, kargs...)
    anim = Animation()
    for t in 1:pasos
        TraficoOpt.paso!(est)
        if t % cada == 0
            frame(anim, dibujar(est; kargs...))
        end
    end
    return anim
end
