# Cambios conceptuales al modelo

Este documento describe las reglas nuevas del **modelo revisado**, el que usa la presentación
`presentacion/presentacion_modelo_nuevo.html`. Solo trata las ideas del modelo. Los errores de
programación que se corrigieron, y en qué parte del código está cada cosa, se describen en
[`CORRECCIONES_AL_CODIGO.md`](CORRECCIONES_AL_CODIGO.md).

## Lo que no cambia

- **La regla de seguimiento.** En cada paso, cada auto elige la velocidad más alta que le deja
  conservar la distancia segura con el de enfrente:
  Δx_s(v) = d_0 + αv²/(2μg) + v·T_reac.
- **La regla del egoísmo.** Un auto se cambia de carril solo si el auto que queda detrás de él en el
  carril nuevo conserva al menos una fracción 1 − ε de su velocidad. ε sigue siendo el único parámetro
  que distingue a un conductor cooperativo (ε = 0) de uno egoísta (ε cercano a 1).
- **Las condiciones de seguridad para cambiarse.** No quedar encimado con los vecinos del carril
  nuevo y quedar a distancia segura del nuevo auto de enfrente.
- **Los parámetros físicos.** v_max = 14 m/s, d_0 = 1.75 m, T_reac = 1 s, auto de 4.5 × 1.8 m,
  δt = 0.1 s.

## 1. Nadie empieza a cambiarse detrás de alguien que se está cambiando

**Antes.** La regla ya estaba en el modelo, pero solo miraba al auto de enfrente en el carril actual,
y por un error de programación casi nunca se cumplía.

**Ahora.** Un auto no empieza un cambio de carril si el auto de enfrente se está cambiando. Esto vale
para el de enfrente en su carril actual y también para el de enfrente en el carril al que quiere
entrar.

**Por qué.** Un conductor no se mete detrás de un auto que todavía está a medio carril: no sabe dónde
va a quedar ese auto.

## 2. El conductor tarda en notar que el de enfrente se está cambiando

**Antes.** El conductor de atrás nunca se enteraba a tiempo de que el de enfrente había empezado un
cambio. Por eso, cuando un carril se desocupaba, medio carril se cambiaba en el mismo instante.

**Ahora.** El conductor nota el cambio del de enfrente hasta que este lleva **1 s** haciéndolo, el
mismo tiempo de reacción T_reac del modelo. Durante ese segundo todavía puede decidir cambiarse él
también.

**Por qué.** Es lo que hace una persona: tarda en ver la direccional y el movimiento del auto. Así
siguen ocurriendo cambios en cadena, pero espaciados y no todos en el mismo instante.

## 3. Filtros antes de la regla del egoísmo

**Antes.** Un auto buscaba otro carril en cada paso, aunque ya fuera libre a su velocidad máxima, y se
cambiaba si el otro carril tenía más espacio enfrente aunque fuera por un milímetro. Sin un umbral ni
una espera, un pelotón entero podía cambiarse de carril y regresar una y otra vez. A baja densidad
había miles de cambios de carril sin razón.

**Ahora.** Antes de aplicar la regla del egoísmo, el auto revisa tres cosas. Si alguna falla, sigue en
su carril:

| Filtro | Valor | Pregunta que se hace el conductor |
|---|---|---|
| Necesidad | 95 % de v_max | ¿Voy más lento de lo que quiero? |
| Ganancia mínima | un largo de auto (4.5 m) | ¿El otro carril tiene claramente más espacio enfrente? |
| Espera | 5 s | ¿Ya pasó un rato desde mi último cambio? |

Si pasa los tres filtros, decide igual que en la tesis: seguridad y egoísmo.

**Por qué.** Una persona no se cambia de carril si ya va bien, ni por una ventaja que no se nota, ni
justo después de acabar de cambiarse. La regla del egoísmo queda intacta: los filtros solo deciden
cuándo un conductor tiene motivo para buscar otro carril. Lo que ε decide, a quién está dispuesto a
frenar, no cambia.

**Por qué van juntos los cambios 2 y 3.** Con solo el tiempo de reacción aparece un vaivén de
pelotones a baja densidad. Con solo los filtros, el efecto del egoísmo casi desaparece. Juntos dan un
modelo sin esos artefactos en el que el egoísmo sigue teniendo efecto.

## 4. Probado, pero fuera del modelo revisado: aceleración realista (IDM)

En el modelo de la tesis un auto puede pasar de 14 m/s a 0 en un solo paso de 0.1 s; en las
simulaciones se midieron aceleraciones de hasta 140 m/s², unas 14 veces la gravedad. Se probó el
Intelligent Driver Model (Treiber, Hennecke y Helbing, 2000), en el que la aceleración y el frenado
están acotados:

| Cantidad | Valor |
|---|---|
| Aceleración máxima | 1.05 m/s² |
| Frenado cómodo | 2.1 m/s² |
| Frenado de emergencia | 8.75 m/s² |
| Separación mínima en reposo | 1.05 m |

Con 2 carriles funciona bien y da más flujo en densidades medias. Con 3 y 4 carriles el tráfico se
atora, porque la regla de cambio de carril sigue pidiendo la distancia segura de la tesis, mucho mayor
que el hueco con el que el IDM sigue a otro auto. Para usarlo hace falta una regla de cambio de carril
pensada para él, como MOBIL (Kesting, Treiber y Helbing, 2007), cuyo factor de cortesía es parecido a
ε. Por eso el modelo revisado conserva la regla de velocidad de la tesis.

## Resultados

- `presentacion/presentacion_modelo_nuevo.html`: los pasos de la tesis, modelo original contra
  modelo revisado.
- `validacion/hallazgos_experimental.md`: tablas de cada etapa de las pruebas.

## Trabajo futuro: perturbaciones

Con el modelo revisado, el tráfico en el anillo llega a un estado estable en el que nadie vuelve a
cambiarse de carril (ver `validacion/hallazgos_experimental.md`, secciones 7 y 8). El egoísmo solo
pesa mientras los autos se redistribuyen después de un arranque desbalanceado. Para estudiar su
efecto en régimen hace falta algo que siga perturbando el tráfico:

- **Entradas y salidas, como en una avenida.** Autos nuevos que entran por un carril y autos que
  salen, en lugar del anillo cerrado. Cada entrada crea un desbalance local que obliga a cambiarse
  de carril.
- **Frenadas al azar.** Una pequeña probabilidad de frenar sin motivo, como en el modelo de
  Nagel-Schreckenberg, para que aparezcan embotellamientos fantasma.
- **Conductores distintos.** Repartir v_max y el tiempo de reacción entre los autos.
