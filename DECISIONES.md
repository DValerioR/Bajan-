# Bajan! — Registro de decisiones

Este archivo registra cada decisión de diseño con su contexto y su resultado. La fuente de verdad es `DISEÑO.md`; si este registro y el diseño no coinciden, manda `DISEÑO.md` y hay que corregir este archivo. Las decisiones nuevas se agregan al final con el siguiente número libre (D25, D26…) y la fecha.

Estado: D1 a D24 aprobadas por el dueño del proyecto (15/10/2026). Ninguna se vuelve a preguntar. D25 a D27 se aprobaron junto con el resumen de la sección 0 (15/10/2026). D28 es un detalle menor de la etapa 0.

## Riesgos técnicos

**D1. Marco de referencia dentro del camión**
- *Contexto:* el personaje (`CharacterBody3D`) se mueve bien en coordenadas locales del camión, pero los ragdolls, las monedas y los objetos lanzados son `RigidBody3D` en el mundo. Mezclar los dos marcos da errores al agarrar, lanzar o salir volando.
- *Decisión:* al inicio de la etapa 2 se hace un prototipo mínimo de dos o tres enfoques (interior físico separado, todo en el mundo con fuerzas de compensación, o una combinación). Se elige uno juntos y se define qué pasa al cruzar la frontera entre interior y mundo.
- *Pendiente:* registrar aquí el enfoque elegido y por qué.
- *Secciones:* 7.2, etapa 2.

**D2. Autoridad en red**
- *Contexto:* si el anfitrión simula todo, caminar dentro de un camión que se sacude se siente con retraso en los clientes.
- *Decisión:* cada jugador tiene autoridad sobre su propio movimiento dentro del camión, con validación simple del anfitrión. El anfitrión mantiene la autoridad sobre el camión, los eventos, los empujones y los ragdolls.
- *Secciones:* 7.2, 11.

**D3. Bots**
- *Contexto:* un bot chofer con IA completa sería casi un juego aparte, y los bots del interior tienen que moverse en un camión que se sacude.
- *Decisión:*
  - El bot chofer es de línea fija y maneja mal a propósito. Usa los mismos controles que un jugador, y ese mismo conductor se reutiliza en los rivales.
  - Mientras maneja un bot, los eventos que exigen reaccionar se simplifican.
  - Los bots del interior se mueven por puntos de paso con una máquina de estados sencilla, usan la misma física que los jugadores y se agarran de los pasamanos, a veces sin alcanzarlos.
- *Secciones:* 5.2, 7.3.

**D4. Presupuesto de ragdolls**
- *Contexto:* 15 pasajeros con ragdoll desmembrable más su sincronización por red es la meta más cara del proyecto.
- *Decisión:* los pasajeros tranquilos son cuerpos simples o animados, el ragdoll se activa solo con golpes fuertes y hay un máximo configurable de ragdolls activos a la vez.
- *Secciones:* 7.5, etapa 3.

## Diseño base

**D5. Daño del camión**
- *Contexto:* la partida terminaba "si el camión queda destruido", pero no había ningún modelo de daño.
- *Decisión:* una barra de integridad es la mecánica real, y además hay piezas que se caen como efecto cómico. Lo dañan los choques, los baches grandes y los rivales, y la tiendita repara o protege.
- *Secciones:* 7.4.

**D6. Desmembramiento**
- *Contexto:* no estaba asignado a ninguna etapa.
- *Decisión:* el ragdoll llega en la etapa 3 y el desprendimiento en la 7, solo como efecto cómico. Aplica a pasajeros y jugadores, y a los jugadores se les restauran las extremidades al reaparecer.
- *Secciones:* 8.

**D7. Maniquí en la etapa 2**
- *Contexto:* la etapa 2 pedía lanzar pasajeros, que todavía no existen.
- *Decisión:* se usa un maniquí físico de prueba.
- *Secciones:* etapa 2.

**D8. Shader toon**
- *Contexto:* se quería desde el inicio, pero estaba asignado a la etapa 7.
- *Decisión:* shader toon y contorno básicos desde la etapa 1, pulidos en la 7.
- *Secciones:* 3, etapas 1 y 7.

**D9. Voceador y vendedor**
- *Contexto:* sus mecánicas eran vagas.
- *Decisión:*
  - Máximo dos acciones por rol.
  - El voceador grita para atraer pasajeros, con barra de aliento, y ayuda a subirlos. El grito va primero por teclado (6A) y después con micrófono (6D). El micrófono solo mide volumen, tiene calibración y no promete cancelación de eco.
  - El vendedor jugador viaja siempre a bordo; el bot sube solo en algunas paradas.
- *Secciones:* 5.1, 10.1.

**D10. "Tírame paro" y chofer fuera del camión**
- *Contexto:* había casos límite sin definir en la rotación y cuando el chofer sale volando.
- *Decisión:*
  - Sin teletransporte: la rotación ocurre en la parada y los jugadores caminan a sus puestos.
  - El camión no arranca sin chofer.
  - Si el chofer sale volando, el camión desacelera y cualquier jugador puede tomar el volante sin cambiar de rol. Si nadie lo toma, los pasajeros se desesperan y luego entra el bot.
  - Al llegar a la parada se cobra la penalización "el chofer no entregó el camión".
- *Secciones:* 5.3.

**D11. Dinero**
- *Contexto:* no estaba definido si el dinero era común o individual, ni qué pasaba con las monedas tiradas.
- *Decisión:* fondo común. Las monedas del piso las recoge cualquiera y las que salen por la ventana se pierden. Si el fondo no alcanza para reaparecer, el jugador queda como espectador.
- *Secciones:* 6.1, 6.3.

**D12. Jugadores 5 a 8**
- *Contexto:* los pasajeros jugables no tenían mecánicas.
- *Decisión:* quedan fuera de la v1, con un máximo de 4 jugadores. Se conserva `MAX_JUGADORES` para ampliarlo después.
- *Secciones:* 1, 11.

**D13. Nombre y contenido**
- *Contexto:* "Bajan" es el gentilicio de Barbados en inglés, y la sangre obliga a llenar el cuestionario de contenido maduro de Steam.
- *Decisión:* se mantiene "Bajan!", con un subtítulo provisional en inglés ("The Chaotic Microbus Game"). La v1 sale sin sangre y el Modo Streamer queda pospuesto. Verificación: no existe otro "Bajan!" en Steam (solo "Bajan Ball Z") ni en itch.io (comprobado a mano por el dueño), aunque no se revisaron marcas registradas. Se vuelve a verificar en la etapa 9.
- *Secciones:* 0, 8, etapa 9.

**D14. Scripts de arranque**
- *Contexto:* el documento original no les daba nombre.
- *Decisión:* `ejecutar.bat` abre el editor y `jugar.bat` lanza el juego.
- *Secciones:* 2, etapa 0.

## Dinero, espectadores y etapas

**D15. Caja chica y cuota**
- *Contexto:* faltaba cómo empieza el fondo en cada ruta y cómo se mide la cuota.
- *Decisión:*
  - La primera ruta empieza con la caja chica `C`. Las siguientes empiezan con lo guardado más el 50 % de `C`.
  - La cuota se mide contra la ganancia de la ruta y se paga del fondo, que nunca queda en negativo. Hay una prueba automática que lo verifica.
- *Secciones:* 6.1, etapa 4.

**D16. Espectador**
- *Contexto:* no estaba definido qué hace un jugador mientras es espectador.
- *Decisión:* tiene cámara libre entre sus compañeros, puede mandar emotes y texto, y ve cuánto dinero falta para volver.
- *Secciones:* 6.3.

**D17. División de la etapa 6**
- *Contexto:* la etapa 6 era demasiado grande.
- *Decisión:* se divide en 6A (roles y bots), 6B (modos, sustitución y espectadores), 6C (tiendita) y 6D (micrófono).
- *Secciones:* 12.

**D18. Valores por defecto**
- *Contexto:* detalles menores que el dueño no objetó.
- *Decisión:*
  - La mercancía del vendedor es limitada y se repone gratis en algunas paradas.
  - Si el chofer está de espectador, su sustituto sigue manejando y un bot cubre el puesto que dejó.
  - Todas las penalizaciones van en configuración.
  - En "Tírame paro" el anfitrión reparte los roles con el último rol que reporta cada jugador.
- *Secciones:* 5.1, 5.3, 6.2.

## Casos límite

**D19. Ajustes de penalizaciones, pasajeros y etapas**
- *Contexto:* una revisión del diseño encontró huecos en el dinero y en casos límite.
- *Decisión:*
  - Salvo la de reaparecer, ninguna penalización deja el fondo en negativo: si no alcanza, el fondo queda en 0.
  - "El chofer no entregó el camión" se cobra una vez por incidente.
  - Un bot del interior que sale volando cuesta la mitad del pasaje y vuelve a subir en la siguiente parada.
  - Los espectadores no entran en la rotación.
  - Al vendedor que se queda abajo lo lleva un taxi pagado por el equipo.
  - Cada pasajero tiene una parada de destino: en cada parada bajan solo algunos y sube una cantidad aleatoria, para que se sienta como una ruta.
  - Jugando solo, quedar de espectador termina la partida.
  - En la etapa 4, sin espectadores todavía, se reaparece sin pagar si el fondo no alcanza.
  - El ragdoll del jugador llega en la etapa 3; en la etapa 2 solo hay caída simple.
- *Secciones:* 5.1, 5.3, 6.0, 6.2, 6.3, 8, etapas 2 a 4.

**D20. Ventana de parada**
- *Contexto:* faltaba definir cuánto dura una parada y qué pasa dentro de ella.
- *Decisión:*
  - Cada parada tiene una ventana configurable con temporizador visible.
  - Dentro de ella ocurren el grito, la subida y bajada de pasajeros, la rotación (con unos segundos extra) y el reabastecimiento.
  - El chofer puede salir antes. Si se pasa del tiempo, los pasajeros se desesperan.
  - El bot chofer sale al terminar la ventana.
- *Secciones:* 5.3, 6.0, 7.3, etapa 4.

**D21. Chofer reaparecido en "Tírame paro"**
- *Contexto:* chocaban la regla de "el chofer retoma el volante" y la rotación de roles.
- *Decisión:* en "Tírame paro" el chofer que reaparece entra a la rotación de esa parada y no retoma el volante, porque la rotación disuelve la sustitución. En Modo normal sí lo retoma. La penalización se cobra una vez por incidente.
- *Secciones:* 5.3, etapa 6B.

**D22. Jugadores en tierra**
- *Contexto:* un jugador podía quedarse en tierra sin salir volando, y no estaba claro si le tocaba taxi o reaparecer.
- *Decisión:* quien se queda en tierra sin haberlo elegido se trata como si hubiera salido volando: penalización de reaparecer, o espectador si el fondo no alcanza. El taxi es solo para el vendedor que bajó a reabastecer por elección propia.
- *Secciones:* 5.1, 6.2, etapa 6B.

**D23. Bot chofer sujeto**
- *Contexto:* si el bot chofer saliera volando, no habría quién lo cubra.
- *Decisión:* va sujeto al asiento y no puede salir volando.
- *Secciones:* 5.3, 6.2, 7.3, etapa 5.

**D24. Espectador en Modo normal**
- *Contexto:* no estaba definido qué rol toma un espectador al volver en Modo normal, donde los roles son fijos.
- *Decisión:* en Modo normal recupera su rol original, que cubría un bot. En "Tírame paro" toma el rol libre o cubierto por un bot.
- *Secciones:* 5.3, etapa 6B.

## Reglas generales

**Regla de complejidad**
- *Contexto:* las reglas de borde ya son muchas y pueden frenar el núcleo del juego.
- *Decisión:* si una regla de borde cuesta mucho más que las demás o no se puede probar fácil, se simplifica o se pospone hasta que el núcleo sea divertido, avisando al dueño con una propuesta. El núcleo es conducir, caminar dentro del camión, los pasajeros, el cobro y la ruta. La etapa 6B puede dividirse más si se propone antes de empezarla.
- *Secciones:* 13.

## Decisiones del desarrollo

Aquí se agregan las decisiones que se tomen durante el desarrollo: la elección de D1, la versión de Godot, el uso de Jolt, el formato y la escala de los modelos, etc. Formato: número, fecha, contexto, decisión y secciones afectadas.

**D25. Versión de Godot** (15/10/2026, aprobada)
- *Contexto:* el diseño pide Godot 4.5.x o la versión estable más reciente que sea compatible con GodotSteam. A esta fecha, la estable más reciente es Godot 4.7.2 (18/08/2026), y GodotSteam publica versiones para 4.7.2 con Steamworks 1.65. La 4.5 ya solo tiene soporte parcial.
- *Decisión:* usar Godot 4.7.2 estable, versión estándar (GDScript, sin .NET), con Jolt Physics como motor 3D, que ya viene integrado en Godot. Al iniciar la etapa 0 se volvió a revisar GodotSteam: su repositorio de GitHub quedó archivado y publica en Codeberg. Sus versiones recientes (4.21 a 4.23, Steamworks 1.65, de julio a octubre de 2026) se anuncian para Godot 4.x, y su blog confirma soporte para 4.7.2. Se descargó el ejecutable oficial y se verificó su SHA512.
- *Secciones:* 2, etapa 0.

**D26. Bot chofer antes de que exista** (15/10/2026, detalle menor)
- *Contexto:* D20 pone en la etapa 4 que el bot chofer sale al terminar la ventana de parada, pero el conductor de línea fija se construye hasta la etapa 5 y el bot chofer hasta la 6A.
- *Decisión:* en la etapa 4 solo maneja el jugador, y la ventana de parada se implementa con su temporizador y la desesperación de los pasajeros. La salida automática del bot al terminar la ventana se conecta cuando el bot existe (etapas 5 y 6A).
- *Secciones:* 6.0, etapas 4, 5 y 6A.

**D27. App ID de Steam para pruebas** (15/10/2026, detalle menor)
- *Contexto:* los lobbies de GodotSteam necesitan un App ID. El propio solo existe después de registrar el juego en Steamworks, que tiene costo.
- *Decisión:* en la etapa 8 se prueba con el App ID 480 (Spacewar), el de pruebas que usa GodotSteam, hasta que el dueño registre el juego. Registrar la app en Steamworks es una tarea del dueño antes de la etapa 9.
- *Secciones:* 11, etapas 8 y 9.

**D28. Herramientas y sistemas base de la etapa 0** (15/10/2026, detalle menor)
- *Contexto:* la etapa 0 necesitaba decidir dónde vive Godot, cómo se traducen los textos y dónde se guardan los ajustes.
- *Decisión:*
  - **Godot portátil:** vive en `herramientas/godot/`, ignorado por git (pesa 180 MB) y por Godot (`.gdignore`). Los `.bat` lo usan desde ahí.
  - **Traducciones:** un solo `traducciones/textos.csv` con columnas `es` y `en`, importado por Godot. Los nodos usan claves y se traducen solos (auto_translate). Los `.translation` generados se versionan para que una copia nueva abra sin errores antes de importar.
  - **Configuración:** los números de diseño van en `config/juego.cfg`, leídos por el autoload `Config`. Las preferencias del jugador (idioma) van en `user://preferencias.cfg`, manejadas por el autoload `Preferencias`, y no forman parte del estado de la partida.
  - **Pruebas automáticas:** escenas en `pruebas/`, corridas en modo headless con `pruebas.bat`.
  - **Pendiente para la etapa 9:** al exportar, hay que incluir `config/*.cfg` en los filtros de exportación, porque no son recursos de Godot.
- *Secciones:* 2, etapa 0.
