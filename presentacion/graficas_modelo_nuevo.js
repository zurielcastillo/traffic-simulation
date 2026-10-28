// Gráficas que no estaban en la presentación de la tesis. Usa `graf`, `lin`, `xy`, `leyenda` y `C`,
// definidas en el código de la presentación original.

// Antes y ahora: velocidad terminal contra ε, modelo de la tesis contra modelo revisado
leyenda('leyAA', [['#98a1ae', 'modelo de la tesis'], [C('--ego'), 'modelo revisado']]);
for (const r of ['0.47', '0.53']) {
  const id = 'gAA' + r.slice(2);
  graf(id, [lin(G.antes[r].map(([x, y]) => ({x, y})), '#98a1ae', {pointRadius: 2, borderDash: [6, 4]}),
            lin(G.ego[r].map(([x, y]) => ({x, y})), C('--ego'), {pointRadius: 2})],
       'egoísmo ε', 'velocidad terminal (m/s)', {x: {min: 0, max: 1}, y: {min: 0, max: 7}});
}

// Más carriles: egoísmo en ρ = 0.53 y flujo por carril con ε = 0
const CN = {'2': C('--coop'), '3': '#9b8cff', '4': C('--ego')};
leyenda('leyN', ['2', '3', '4'].map(k => [CN[k], k + ' carriles']));
graf('gN53', ['2', '3', '4'].map(k => lin(G.n[k].ego53.map(([x, y]) => ({x, y})), CN[k], {pointRadius: 2})),
     'egoísmo ε', 'velocidad terminal (m/s)', {x: {min: 0, max: 1}, y: {min: 0}});
graf('gNq', ['2', '3', '4'].map(k => lin(xy(G.rho, G.n[k].q0), CN[k])),
     'densidad ρ', 'flujo por carril (autos/s)', {x: {min: 0, max: 1}, y: {min: 0}});
document.getElementById('nGraves').textContent = G.n['3'].grave;
