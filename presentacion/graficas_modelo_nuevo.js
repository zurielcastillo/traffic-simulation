// notas que dependen de la condición inicial, se agregan al texto de la sección del barrido fino
const NOTA_FINO = {
  fino: ' Este es el arranque de la tesis: un carril lleno y el otro vacío provocan cientos de cambios de carril al principio (unos 330 por corrida).',
  fino_desorden: ' Con el arranque desordenado casi nadie se cambia de carril (menos de 3 cambios por corrida): el seguimiento empareja los huecos en pocos segundos y ningún carril llega a tener un largo de auto más de espacio. El egoísmo no tiene efecto.',
  fino_uniforme: ' Con el arranque parejo nadie se cambia de carril en ninguna corrida: los dos carriles quedan iguales y no hay motivo para cambiarse, así que el egoísmo no tiene oportunidad de actuar.',
};
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

// Barrido fino: pérdida de velocidad contra densidad para cada ε (promedio de 5 semillas y franja min-máx).
// Se puede cambiar entre la condición inicial de la tesis (G.fino) y la pareja (G.fino_uniforme).
(function () {
  const CF = {'0.7': '#8fd6b0', '0.79': '#d8c368', '0.89': C('--ego'), '1.0': C('--freno')};
  const es = Object.keys(CF);
  leyenda('leyFino', es.map(e => [CF[e], 'ε = ' + e]));
  let grafica = null;
  function dibuja(clave) {
    const F = G[clave];
    const ds = [];
    for (const e of es) {
      const d = F.eps[e], c = CF[e];
      // franja: primero el borde inferior (sin relleno) y luego el superior rellenado hasta el anterior
      ds.push(lin(xy(F.rho, d.min), c, {borderWidth: 0, pointRadius: 0, fill: false}));
      ds.push(lin(xy(F.rho, d.max), c, {borderWidth: 0, pointRadius: 0, fill: '-1', backgroundColor: c + '22'}));
      ds.push(lin(xy(F.rho, d.media), c, {pointRadius: 2.5}));
    }
    if (grafica) grafica.destroy();
    grafica = graf('gFino', ds, 'densidad ρ', 'pérdida de velocidad (%)', {x: {min: 0.35, max: 0.65}, y: {min: 0, max: 60}});
    // rango donde algún ε ≥ 0.7 pierde 10 % o más en promedio
    const dentro = F.rho.filter((r, i) => es.some(e => F.eps[e].media[i] >= 10));
    $('fRango').textContent = dentro.length ? `${dentro[0].toFixed(2)} – ${dentro[dentro.length - 1].toFixed(2)}` : 'ninguno';
    let mejor = {p: -1};
    for (const e of es) F.eps[e].media.forEach((p, i) => { if (p > mejor.p) mejor = {p, e, r: F.rho[i]}; });
    $('fMax').textContent = `−${Math.round(mejor.p)} %`;
    $('fMaxTxt').textContent = `mayor pérdida promedio, en ρ = ${mejor.r.toFixed(2)} con ε = ${mejor.e}`;
    // las frases sobre ε = 0.5 y las franjas solo aplican cuando sí hay efecto (arranque de la tesis)
    const general = clave === 'fino' ?
      `Con ε = 0.5 la pérdida nunca pasa de ${Math.round(Math.max(...F.eps['0.5'].media))} %: el egoísmo solo pesa cuando es alto. ` +
      `Las franjas anchas muestran que el resultado depende mucho de cómo arrancan los autos: en la misma densidad una corrida puede perder la mitad de su velocidad y otra casi nada. ` : '';
    $('fNota').textContent = general + `Hubo choques en ${F.choques} de ${F.corridas} corridas.` + (NOTA_FINO[clave] || '');
  }
  const sel = $('selFino');
  // solo se muestran los botones de las condiciones iniciales que tienen datos
  sel.querySelectorAll('button').forEach(b => { if (!G[b.dataset.k]) b.hidden = true; });
  sel.addEventListener('click', ev => {
    const b = ev.target.closest('button'); if (!b) return;
    sel.querySelectorAll('button').forEach(x => x.setAttribute('aria-pressed', x === b));
    dibuja(b.dataset.k);
  });
  dibuja('fino');
})();
