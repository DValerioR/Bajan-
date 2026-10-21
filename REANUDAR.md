# Para reanudar el desarrollo de Bajan!

Estado al 20/10/2026. Todo está en GitHub y todas las pruebas pasan
(`pruebas.bat`, etapas 0 a 6B, unos 45 minutos).

## Qué está hecho

| Etapa / cambio | Commit | Decisión |
|---|---|---|
| Etapas 0 a 5 (camión, interior, pasajeros, dinero y ruta, eventos y rivales) | `90ef41e` y anteriores | D25–D43 |
| Camión de 3 m con pasillo para dos, sentarse con C, mejor caminado | `a99d587` | D44 |
| Personajes sin huecos ni grietas (Blender tapa los cortes) | `12ae300` | D45 |
| Caras nítidas: textura propia de 2048 px y contorno sin astillas | `6caaffa` | D46 |
| **6A:** los cuatro roles (chofer, cobrador, voceador, vendedor), bots del interior, puerta física | `5c3fa16` | D47 |
| Brazo y manga del voceador | `b1f57a6`, `874530f` | — |
| **6B1:** "Tírame paro" (rotación de puestos), el chofer con cuerpo al volante | `874530f` | D48 |
| **6B2:** el chofer sale volando, bot sustituto, "el chofer no entregó el camión" | `924f140` | D49 |
| Caras animadas (parpadeo y boca) del voceador y el niño | `b60b810` | D50 |
| Fresa nueva (modelo suelto en pose T), con cara animada | `8b202ab` | D50 |
| Gótica (pasajera) y ladrón, con el evento de robo | `d4e05ce` | D51 |
| Monedas que se salían del camión; rodillas y codos | `97e95bf` | — |
| **Personajes con esqueleto** (piel continua, ragdoll sobre huesos) | `db03ce4` | D52 |
| Ragdoll ligero: manos a la agarradera, pies en el piso, cadera en el asiento, resorte | `0bbaf29` | D52 |

## Qué sigue

**Físicas de los personajes** (el dueño pidió arreglarlas antes de seguir con funciones, D52): ya
están el esqueleto y el ragdoll ligero (manos a la agarradera, pies en el piso, cadera sobre el
asiento, resorte con los empujones). Hombros y texturas afinados (pesos automáticos y textura horneada desde el modelo completo).

Luego la 
**etapa 6B3** (la última parte de la 6B, ver D48): releer DISEÑO.md secciones 5.1, 6.2 y 6.3.
- Penalización "bot fuera del camión": si un bot del interior sale volando, el equipo paga la mitad
  del pasaje y el bot vuelve a subir en la siguiente parada (hoy vuelve gratis).
- Taxi del vendedor: si el camión deja abajo al vendedor jugador mientras reabastece por elección
  propia, el equipo paga el taxi que lo lleva a la siguiente parada.
- Jugadores en tierra (D22): quien se queda abajo sin haber bajado por elección propia se trata
  como si hubiera salido volando.
- Espectadores (6.3, D24). Jugando solo, quedarse sin dinero para reaparecer termina la partida
  (D19, el dueño lo confirmó el 18/10/2026).

Después vienen la 6C (tiendita), la 6D (micrófono), la 7 (estilo y pulido), la 8 (multijugador) y
la 9 (Steam).

## Pendientes y detalles abiertos

- **Balance:** el bot cobrador cobra mucho ($290–350 por ruta contra una cuota de $60); el
  vendedor que no se sujeta pierde la caja muy rápido.
- **Caras animadas:** solo voceador, niño y fresa. Para otro personaje hay que medir `ojos` y `boca`
  en `modelos/personajes.cfg` y correr `procesar_personajes.bat --forzar <nombre>`. Se le ofreció
  al dueño hacerlo con la gótica y el ladrón.
- **Etapa 8:** que otro jugador tome el volante sin dejar su rol, y el chofer espectador (D49).
- La red de seguridad del bot chofer (`_rescatar_volante` en `escenas/ruta/ruta.gd`) a veces salta
  una vez por ruta; la prueba de la 6B lo tolera.
- Los originales de Tripo (fresa, gótica, ladrón) se respaldaron en una carpeta temporal fuera del
  proyecto; en `modelos/fuentes/` están las versiones aligeradas que usa el procesador.

## Cómo se trabaja

- Se avanza etapa por etapa; al terminar cada etapa o cambio importante se corre `pruebas.bat`
  completo y, si todo pasa, se hace commit y push a `main`.
- Las decisiones van al final de `DECISIONES.md` (la última es D53).
- Personajes nuevos de Tripo **con rig** (la forma preferida, D53): un personaje por modelo, en pose T
  o A, con los brazos separados y el rig automático de Tripo. El FBX va en `modelos/fuentes/<nombre>/`,
  se agrega una hoja con `rig`, `nombres`, `altura` y `brazos_caidos` en `modelos/personajes.cfg` y
  se corre `procesar_personajes.bat`. Así se agregaron el señor, la abuelita, el punk, el turista, el viejo, la fresa, la gótica, el ladrón, la señora, el cobrador, el voceador, el albañil, el luchador, el niño, el oficinista y la vendedora; faltan el galán y el chavo. Si Tripo pone la articulación de la cabeza en la boca (revisarlo con Blender), `cabeza_en` la baja a la barbilla. Si el FBX trae
  animaciones: `blender --background --factory-startup --python scripts/herramientas/animaciones_blender.py -- <fbx> animaciones`.
  El dueño va a regenerar así a todos los de las hojas viejas.
- Personajes nuevos de Tripo sin rig (los de antes): se aligeran con Blender (200 000 caras, textura de 4K), se guardan en
  `modelos/fuentes/`, se les agrega una hoja y sus medidas en `modelos/personajes.cfg` y se corre
  `procesar_personajes.bat --forzar <nombre>` (Blender 5.0 une las piezas en una malla con esqueleto,
  reduce, arma la textura, pone la boca animada y comprime la textura). Sin Blender ya no funciona.
