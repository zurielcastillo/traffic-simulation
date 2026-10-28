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

// Barrido fino: pérdida de velocidad contra densidad para cada ε (promedio de 5 semillas y franja min-máx)
(function () {
  const F = G.fino, CF = {'0.7': '#8fd6b0', '0.79': '#d8c368', '0.89': C('--ego'), '1.0': C('--freno')};
  const es = Object.keys(CF);
  leyenda('leyFino', es.map(e => [CF[e], 'ε = ' + e]));
  const ds = [];
  for (const e of es) {
    const d = F.eps[e], c = CF[e];
    // franja: primero el borde inferior (sin relleno) y luego el superior rellenado hasta el anterior
    ds.push(lin(xy(F.rho, d.min), c, {borderWidth: 0, pointRadius: 0, fill: false}));
    ds.push(lin(xy(F.rho, d.max), c, {borderWidth: 0, pointRadius: 0, fill: '-1', backgroundColor: c + '22'}));
    ds.push(lin(xy(F.rho, d.media), c, {pointRadius: 2.5}));
  }
  graf('gFino', ds, 'densidad ρ', 'pérdida de velocidad (%)', {x: {min: 0.35, max: 0.65}, y: {min: 0}});
  // rango donde algún ε ≥ 0.7 pierde 10 % o más en promedio
  const dentro = F.rho.filter((r, i) => es.some(e => F.eps[e].media[i] >= 10));
  $('fRango').textContent = dentro.length ? `${dentro[0].toFixed(2)} – ${dentro[dentro.length - 1].toFixed(2)}` : 'ninguno';
  let mejor = {p: -1};
  for (const e of es) F.eps[e].media.forEach((p, i) => { if (p > mejor.p) mejor = {p, e, r: F.rho[i]}; });
  $('fMax').textContent = `−${Math.round(mejor.p)} %`;
  $('fMaxTxt').textContent = `mayor pérdida promedio, en ρ = ${mejor.r.toFixed(2)} con ε = ${mejor.e}`;
  $('fNota').textContent = `Con ε = 0.5 la pérdida nunca pasa de ${Math.round(Math.max(...F.eps['0.5'].media))} %: el egoísmo solo pesa cuando es alto. ` +
    `Las franjas anchas muestran que, dentro de ese rango, el resultado depende mucho de cómo arrancan los autos: en la misma densidad una corrida puede perder la mitad de su velocidad y otra casi nada, porque basta un cambio de carril agresivo en el momento justo para desatar el embotellamiento. ` +
    `El hueco en ρ = 0.49 aparece en las 5 semillas; probablemente viene de la condición inicial (todos los autos en el carril derecho) y no de un cambio de régimen, pero no lo he comprobado. Hubo choques en ${F.choques} de ${F.corridas} corridas.`;
})();
