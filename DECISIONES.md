# Bajan! — Registro de decisiones

Este archivo registra cada decisión de diseño con su contexto y su resultado. La fuente de verdad es `DISEÑO.md`; si este registro y el diseño no coinciden, manda `DISEÑO.md` y hay que corregir este archivo. Las decisiones nuevas se agregan al final con el siguiente número libre (D25, D26…) y la fecha.

Estado: D1 a D24 aprobadas por el dueño del proyecto (15/10/2026). Ninguna se vuelve a preguntar. D25 a D27 se aprobaron junto con el resumen de la sección 0 (15/10/2026). D28 es un detalle menor de la etapa 0. D29 a D33 son decisiones técnicas de la etapa 1. D34 a D36 son de la etapa 2. D37 y D38 son de la etapa 3.

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

**D29. Modelo de conducción** (15/10/2026, etapa 1)
- *Contexto:* el camión necesita una conducción arcade, exagerada y ajustable que casi nunca se voltee. El `VehicleBody3D` de Godot es más difícil de exagerar y de ajustar.
- *Decisión:* el camión es un `RigidBody3D` con suspensión por rayos (uno por llanta) y fuerzas propias:
  - motor de tracción trasera;
  - frenos que, con el camión parado, meten reversa;
  - agarre lateral con límite (puede derrapar);
  - dirección que se cierra con la velocidad.
  
  Todas las fuerzas se expresan como aceleraciones, así que el manejo no depende de la masa.
  - **Estabilidad:** centro de masa bajo, las fuerzas de las llantas se aplican cerca de ese centro (`altura_fuerzas`) y hay un par que endereza al camión si se ladea de más o va en el aire. Si aun así se voltea, la tecla R lo pone de pie sobre la calle.
  - **Exageración:** el balanceo de la carrocería es solo visual (la física no se mueve). La "patada" de topes empuja hacia arriba la esquina que pega de golpe, como una suspensión que toca fondo. Con `patada_topes=0.45`: a 30 km/h un tope casi no se siente, a 50 km/h el camión brinca y a 70 km/h despega unos instantes.
  - **Separación de la entrada:** el camión solo lee `ComandosConduccion`. Los llena `EntradaChofer` con el jugador, el piloto de las pruebas y, más adelante, el bot o la red.
  - **Ajuste en vivo:** todos los números están en `config/conduccion.cfg` y F9 los recarga sin cerrar el juego.
  - **Medido con las pruebas automáticas:**
    - de 0 a 50 km/h en unos 4 s;
    - frena de 50 a 0 en unos 7 m;
    - agarre lateral máximo de unos 0.66 g;
    - vueltas completas sin pasar de unos 10° de inclinación;
    - volantazo a fondo a 55 km/h sin voltearse.
- *Secciones:* 7.1, etapa 1.

**D30. Cómo se aplica el estilo toon** (15/10/2026, etapa 1)
- *Contexto:* D8 pide shader toon y contorno desde la etapa 1, y los modelos futuros (formas básicas ahora, glTF generados con IA después) deben recibir el mismo estilo sin trabajo extra.
- *Decisión:* las escenas se arman con materiales normales (`StandardMaterial3D`), y `EstiloToon.aplicar()` los convierte al cargar.
  - **Sombreado:** el shader `materiales/toon.gdshader` da luz en dos tonos con un brillo de borde.
  - **Contorno:** `materiales/contorno.gdshader` es un "casco invertido". En cajas se infla por eje para que las esquinas no se abran; en las demás formas se infla por la normal.
  - **Excepciones:** una malla con el metadato `sin_contorno` no lleva contorno (piso, calle). Las piezas repetidas de la calle se dibujan con MultiMesh, sin contorno.
  - **Pendiente:** el grosor y los colores del contorno se pulen en la etapa 7.
- *Secciones:* 3, etapas 1 y 7.

**D31. Lectura directa del ratón para mirar** (15/10/2026, etapa 1)
- *Contexto:* la sección 9 pide que todas las acciones pasen por el sistema de acciones de Godot y nunca leer teclas directo. El movimiento del ratón no es una tecla ni una acción.
- *Decisión:* la cámara del chofer lee `InputEventMouseMotion` directamente para girar la cabeza, como cualquier cámara en primera persona. El stick derecho del mando usa las acciones `mirar_*`. Todas las teclas y botones pasan por acciones.
- *Secciones:* 9.

**D32. Calle de prueba y herramientas de ajuste** (15/10/2026, etapa 1)
- *Contexto:* la etapa 1 pide una calle de prueba con topes, baches y curvas.
- *Decisión:*
  - **Trazado:** la calle es un circuito cerrado de 474 m que se arma desde `config/calle_prueba.cfg` (rectas y curvas, topes, baches y escenario). Tiene dos carriles y se maneja por la derecha.
  - **Baches:** son huecos reales en el asfalto, hasta el piso.
  - **Topes:** cilindros amarillos a lo ancho de la calle.
  - **Escenario:** edificios con tinaco por fuera del circuito y árboles en la banqueta de adentro.
  - **Línea de ruta:** la calle guarda una muestra por metro del centro, que usan el reinicio y el piloto de pruebas. Más adelante la usará el bot chofer.
  - **Herramientas de desarrollo:** `pruebas/captura.tscn` toma capturas desde varias cámaras, y `pruebas/experimento_topes.tscn` mide el brinco en topes con distintos valores. Ninguna de las dos es prueba automática.
- *Secciones:* 4, etapa 1.

**D33. Formato y escala de modelos** (15/10/2026, etapa 1)
- *Contexto:* la sección 3 pide documentar el formato y la escala que se esperan de los modelos que vendrán (incluidos los generados con IA).
- *Decisión:*
  - **Convenciones generales:**
    - Formato glTF 2.0 binario (`.glb`).
    - 1 unidad = 1 metro, Y hacia arriba, el frente del objeto mirando a −Z.
    - Materiales simples con color base (y textura opcional); el estilo toon se aplica solo (D30).
    - Pocas caras: low poly.
  - **Camión:** mide 8.1 m de largo, 2.5 m de ancho y unos 2.75 m del piso al techo.
    - El modelo de la carrocería sustituye al nodo `Carroceria` de `escenas/camion/camion.tscn`. Su origen va al centro del piso del camión, con la puerta del lado derecho al frente.
    - Las llantas van aparte: radio de 0.45 m, eje de giro en X, origen en el centro de la llanta.
  - **Personajes:** ver D34.
- *Secciones:* 3.

**D34. Personajes de muñeco por piezas** (15/10/2026, etapa 2, decidido con el dueño)
- *Contexto:* el dueño subió dos hojas de personajes hechas en Tripo (plan de pago), con 16 personajes en total. Cada hoja es una sola malla de ~1 millón de vértices, sin esqueleto, y pesa 65 MB.
- *Decisión:*
  - **Estilo de muñeco:** cada personaje se corta en 6 piezas rígidas (cabeza, torso, dos brazos y dos piernas) con el giro en su articulación. Así encaja con "las extremidades se desprenden como piezas de muñeco" (sección 8) y es barato de simular y sincronizar. Se anima en código (`scripts/personajes/personaje.gd`), sin esqueleto.
  - **Herramienta:** `procesar_personajes.bat` (`scripts/herramientas/procesar_personajes.gd`):
    1. Separa a cada personaje: al soldar las costuras, cada uno es una malla cerrada.
    2. Lo escala, lo centra entre los pies y lo voltea para que mire a −Z.
    3. Lo corta con las articulaciones medidas a mano en `modelos/personajes.cfg`; la estimación automática queda solo para personajes nuevos sin medidas.
    4. Limpia las islas sueltas y reduce cada pieza con los niveles de detalle de Godot (~5 000 triángulos por personaje).
    5. Guarda en el color de vértice una normal suavizada para el contorno.
  - **Escala:** 3.8 m por unidad de Tripo, lo que da alturas de 1.15 m (abuelita) a 1.98 m (fresa). El origen va entre los pies y el frente mira a −Z. Cada escena guarda en metadatos `altura`, `altura_ojos`, `ancho` y la posición de cada mano relativa a su brazo.
  - **Roles:** los 4 de arriba de Modelos1, de izquierda a derecha, son chofer, cobrador, voceador y vendedora. Los otros 12 son pasajeros.
  - **Archivos:** los originales quedan en `modelos/fuentes/`, ignorados por git y por Godot; el dueño los respalda por su cuenta. Al repositorio solo suben los procesados (`modelos/personajes/`, ~9 MB en total).
  - **Formato editable en Blender** (decidido con el dueño después): cada personaje es un `.glb` (`modelos/personajes/<nombre>.glb`) con sus 6 piezas como objetos separados, con el origen en su articulación, y su propia textura recortada de la hoja original y guardada adentro (JPEG, 1024 px como máximo).
    - **Manda la versión editada:** `procesar_personajes.bat` solo crea los `.glb` que no existen; `--forzar [nombre]` los regenera.
    - **Sin datos aparte:** el juego no guarda medidas aparte; saca la estatura, el cuello, la cadera y la mano de las piezas al cargar, así que respeta lo que se cambie en Blender.
    - **Contorno:** la normal suavizada del contorno se calcula al cargar (una vez por malla) y no va en el archivo, para que en Blender no aparezcan colores de vértice raros.
  - **Pendiente para la etapa 7:** las piezas no tienen tapas en los cortes. Al doblarse mucho se ve el hueco, igual que en un muñeco articulado. Si al desprenderlas se ve mal, se agregan tapas.
- *Secciones:* 3, 8.

**D35. Prototipos del interior (D1)** (15/10/2026, etapa 2, el dueño eligió B)
- *Contexto:* D1 pide probar dos o tres enfoques para caminar dentro del camión antes de construir encima.
- *Decisión:* hay dos prototipos que comparten el mismo personaje (`CuerpoPersonaje`), el mismo modelo de inercia y la misma geometría del interior (sacada de la carrocería).
  - **Modelo de inercia común:** el empujón es la aceleración ficticia del camión, suavizada, exagerada ×1.3 y con tope de 9 m/s². La "firmeza" del personaje lo regresa a donde quiere caminar. Si el empujón pasa de 8 m/s², tropieza; sujeto del pasamanos solo siente el 15 %.
  - **A, interior en el mundo** (`InteriorMundo`): el piso del camión es una plataforma móvil. Godot lleva a los personajes con ella; los objetos sueltos los arrastra la fricción real.
  - **B, interior separado** (`InteriorLocal`): lo que va adentro vive en un espacio de física propio, donde el camión está quieto. Lo que hace el camión llega como gravedad inclinada y empujones con tope, y lo que se ve son reflejos colgados de la carrocería, que se ladean con ella. Al cruzar la puerta o una ventana, el cuerpo pasa al mundo con su velocidad real, y al volver a entrar regresa al espacio del interior.
  - **Medido con `pruebas/prueba_etapa2.tscn`:** los dos dejan caminar de la puerta al fondo con el camión en marcha, aguantan el modo loco sujetos del pasamanos y sacan bien una bolsa por la ventana.
    - A tiene fallas intermitentes en el modo loco: brincos de ~25 cm en un solo cuadro y hundimientos en el piso de hasta ~9 cm.
    - B no tiene ninguna (brincos máximos de 3 a 6 cm, sin hundirse).
  - **Recomendación técnica:** B, por estabilidad, control del caos y porque sincronizar posiciones relativas al camión es más simple en red (etapa 8). Su costo es mantener dos espacios de física y la transición entre ellos.
  - **Resultado:** el dueño probó los dos y eligió **B**. Se borró A y el interior quedó en una sola clase, `InteriorCamion` (con `MarcoInterior`).
- *Secciones:* 7.2, etapa 2.

**D36. Bajar y subir del camión** (15/10/2026, etapa 2, detalle menor)
- *Contexto:* para cerrar la etapa 2 había que comprobar que un personaje puede bajar a la calle y volver a subir. Eso destapó tres problemas: el arco de la llanta delantera tapaba la puerta, el piso del camión queda a 66 cm del suelo y los personajes no subían ni una banqueta.
- *Decisión:*
  - **Eje delantero:** se adelantó de z = −2.75 a −2.1 (la puerta queda delante del eje, como en los micros reales). El centro de masa ahora se calcula entre los dos ejes, y se agregó un freno de estacionamiento sin pedales, para que el camión parado no se arrastre. Las pruebas de manejo siguen pasando.
  - **Escalones de la puerta:** se ven dos escalones y la colisión es una rampa invisible de 33°.
  - **Subir escalones:** los personajes suben solos escalones de hasta 35 cm (banquetas, escalones), pero solo si el obstáculo es fijo, está de frente y el lugar donde aterrizan es plano. Así no se trepan a bolsas, al maniquí ni a las esquinas de los asientos.
- *Secciones:* 7.2, etapa 2.

**D37. Ragdoll de muñeco** (15/10/2026, etapa 3)
- *Contexto:* D4 y la etapa 3 piden ragdolls que se activen solo con golpes fuertes, con un tope de activos, que salgan volando por ventanas y puertas, y que el jugador también caiga como ragdoll.
- *Decisión:*
  - **Armado:** el ragdoll (`Ragdoll`) se arma al momento con las 6 piezas del muñeco, en la pose y el lugar del personaje. Cada pieza es un objeto suelto con una caja del 65 % de su tamaño, unido al torso con una articulación de cono (70° de columpio y 25° de giro). Pesa 60 kg a 1.7 m de altura, escalado según la estatura.
  - **Cuándo se cae:** al pasar `umbral_empujon` (8.8 m/s² de empujón del camión, solo si va de pie y sin sujetarse) o `umbral_golpe` (4 m/s de golpe directo: un empujón, una bolsa, otro pasajero que le cae encima).
  - **Gestor:** `GestorRagdolls` respeta `max_activos` (6); si ya hay tantos, el personaje solo tropieza. Mientras tanto, el personaje se apaga; cuando el ragdoll se queda quieto (o pasan 6 s), se levanta donde quedó el torso, adentro o en la calle.
  - **Entidades de varios cuerpos:** el interior ahora maneja entidades de varios cuerpos, así que un ragdoll entero cruza la puerta o una ventana con la velocidad correcta. La cámara del jugador sigue la cabeza del ragdoll.
  - **Recoger:** las piezas son objetos sueltos, así que se pueden agarrar y lanzar.
  - **Ventanas y puertas:** que alguien salga por una ventana depende del ángulo, porque los respaldos y los pilares lo atajan. Por la puerta sale bien (hay prueba automática). Por la ventana se comprobó con capturas (`pruebas/captura_ventana.tscn`).
- *Secciones:* 7.5, 8, etapa 3.

**D38. Pasajeros y paradas** (15/10/2026, etapa 3)
- *Contexto:* la etapa 3 pide pasajeros que suban y bajen en las paradas y se agarren de los pasamanos, y la sección 6.0 (D19) pide que en cada parada bajen solo algunos.
- *Decisión:*
  - **Paradas:** la calle de prueba tiene 5 (poste con letrero bilingüe y banca), definidas en `config/calle_prueba.cfg`. El piloto automático frena suave para dejar la puerta frente al poste, espera 8 s (hasta 8 s más si todavía hay gente subiendo o bajando) y sigue.
  - **Pasajeros:** `GestorPasajeros` usa una máquina de estados sencilla con un `CuerpoPersonaje` normal por pasajero: esperar, subir, ir a su lugar, ir sentado o de pie, bajar y alejarse. Cada uno elige una parada de destino a 1–3 paradas, así que en cada parada bajan unos y suben otros.
  - **Lugares:** prefieren asiento (12) y, si no hay, van de pie en el pasillo (5 lugares), sujetos del pasamanos. Para sentarse llegan al pasillo frente a su asiento. Los sentados no reciben empujones.
  - **Si salen volando:** el que acaba en la calle sin haber llegado a su destino se pierde y se va (en la etapa 4 será pasaje perdido).
  - **Pasillo:** los pasajeros no chocan entre sí ni contra el jugador (se escurren, como en un micro lleno); el jugador sí choca contra ellos.
  - **Configuración:** todo está en `config/pasajeros.cfg`: capacidad 15, llegadas, modelos, etc.
  - **Errores corregidos en el camino:**
    - Al detenerse, el piloto pisaba el freno y el camión se echaba en reversa (con el camión parado, el freno mete reversa). Ahora suelta los pedales y actúa el freno de estacionamiento.
    - Las pruebas ahora fallan si se corren menos verificaciones de las esperadas, para que un script que no compila no pase como "todo bien".
  - **Rendimiento medido con 15 pasajeros a bordo en modo loco:**
    - Simulación de unos 2 ms por cuadro, sin dibujar.
    - ~880 cuadros por segundo a 1080p con la RTX 5070.
    - 56–60 cuadros por segundo a 1080p con la GPU integrada Intel del mismo equipo, que es mucho más débil que una tarjeta de gama media.
- *Secciones:* 4, 6.0, 7.5, etapa 3.

**D39. Rol del jugador y morral del cobrador** (15/10/2026, etapa 4)
- *Contexto:* la etapa 4 pide una ruta completa con cobro y cuota. Según D26, en esta etapa solo maneja el jugador, pero para probar el cobro hace falta alguien cobrando mientras el camión anda.
- *Decisión:* en la escena de ruta, el jugador es el **cobrador** y el piloto automático hace de chofer, como sustituto del bot chofer de la etapa 6A. Esto amplía D26: manejar como jugador sigue disponible en la calle de prueba. El dueño lo confirmó.
  - **Cobro:** con F (mando B), le cobras al pasajero que tengas enfrente (`alcance` 1.6 m). Cada pasajero paga su pasaje una vez y queda marcado con "$". El que se baja sin pagar cuenta como dinero perdido.
  - **Morral (mecánica nueva, no viene en DISEÑO.md):** lo cobrado se guarda en el morral y se entrega al fondo en cada parada. Si tropiezas, se riega el 30 %; si caes como ragdoll, se riega todo, en monedas físicas de $2 (máximo 12). Se recogen caminando encima de ellas. Las que caen a la calle se pierden a los 3 s. Así el caos del camión le cuesta dinero al cobrador. Las monedas tienen fricción alta, no rebotan y no ruedan de canto: en la primera versión se salían rodando por la puerta y se perdía el 80 % de lo cobrado.
  - **Balance medido:** en la ruta de prueba, un cobrador que va sujeto y le cobra a todos junta unos $210 contra una cuota de $60. Es holgado a propósito, porque los eventos y rivales de la etapa 5 van a apretar; el balance fino se hace después.
  - **Ventana de parada (D20):** dura 10 s. En ese tiempo, a los que quieren bajar les sube la desesperación, y pueden bajarse enojados sin pagar.
  - **Reaparecer:** si el jugador se queda abajo, reaparece en la siguiente parada pagando la penalización ($20). Si el fondo no alcanza, reaparece gratis (en la etapa 4 no hay otro castigo).
  - **Cierre de ruta:** en la terminal, cuando todos bajaron o pasó la ventana, se cierra la ruta contra la cuota (`Juego.cerrar_ruta`). Se muestra el resultado y se sigue a la siguiente ruta o, sin cuota cumplida, termina la partida.
  - **Configuración:** los números están en `config/partida.cfg` y el estado de la partida en el autoload `Juego` (`EstadoDinero`).
- *Secciones:* 5, 6.0, 6.2, etapa 4.

**D40. Generador de rutas por tramos** (15/10/2026, etapa 4)
- *Contexto:* la sección 4 pide rutas distintas cada vez, con zonas (popular, centro, lujo, cruces) y dificultad creciente.
- *Decisión:* `GeneradorRuta` encadena tramos prediseñados de `config/tramos.cfg` (12 tramos: 4 zonas × dificultad 1–3), a partir de una semilla:
  - **Paradas:** de 6 a 10 por ruta, contando la terminal. Hay una recta de salida y una de llegada, y las paradas van en tramos rectos.
  - **Zonas:** ninguna se repite más de dos veces seguidas. La dificultad sube con el avance dentro de la ruta y de una ruta a la siguiente.
  - **Sin enroscarse:** las curvas se voltean en espejo para que el rumbo no se aleje más de 70° del de salida, así la ruta nunca se cruza consigo misma.
  - **Paradas despejadas:** no queda ningún tope ni bache a menos de 12 m de una parada. Un tope junto a la parada atoraba al camión al arrancar.
  - **Calle libre:** los edificios iban girados (el frente largo apuntaba hacia la calle) y en las curvas sus esquinas invadían el carril; eso atoraba al camión. Ahora se revisa la planta de cada edificio contra la calle: si invade, se prueba con la mitad del frente y, si aun así invade, no se pone. Hay una prueba que pasa una caja del ancho de la calle por 6 rutas completas.
  - **La calle:** la clase `Calle` (antes la pista de prueba) arma tanto el circuito de prueba como estas rutas abiertas, con piso a la medida, letreros de zona, colores por zona y una barrera al final.
- *Secciones:* 4, etapa 4.

**D41. Modelos sueltos y en pose T** (15/10/2026, detalle menor)
- *Contexto:* el dueño cambió el modelo del chofer por uno suelto de Tripo, en pose T y con otra escala.
- *Decisión:* `procesar_personajes` acepta hojas de un solo personaje con su propia estatura (`altura`), textura y número de triángulos. Un modelo en pose T (`brazos_caidos`) se corta con los brazos extendidos y luego se giran en el hombro, para que en reposo cuelguen como los demás (la animación lo da por hecho). El chofer nuevo mide 1.72 m y va sin reducir (10 044 triángulos), porque reducirlo manchaba la textura. Su original está en `modelos/fuentes/chofer.glb`.
- *Secciones:* 3.

**D42. Conductor de línea fija y chofer visible** (15/10/2026, etapa 5)
- *Contexto:* la sección 7.3 pide un conductor de línea fija que maneje mal a propósito, que usen los rivales y después el bot chofer, y D23 pide que vaya sujeto al asiento sin poder salir volando.
- *Decisión:* el `PilotoAutomatico` es ese conductor. Escribe en los mismos comandos que un jugador (acelerar, frenar, girar) y no esquiva nada.
  - **Manejo malo:** se pasa hasta 1.5 m de la parada, abre las curvas cerradas hasta 0.8 m y mete frenazos, acelerones y volantazos según el modo (`config/interior.cfg`, sección `[piloto]`).
  - **Eventos:** solo frena ante lo que el gestor de eventos le marca con `alto_en` (animales, valla, el rival de enfrente) y respeta un tope de velocidad temporal (el bache gigante). Puede ir por el carril izquierdo (`carril`) y más rápido (`factor_velocidad`); así rebasan los rivales.
  - **Atorones:** si se estrella o se sube a la banqueta y no avanza en 3 s, se echa en reversa con el volante al revés. Si después de tres intentos sigue atorado, el camión vuelve a su carril, que es lo único que hace sin manejar. Pasa sobre todo con la calle mojada; sin esto, la ruta se quedaba trabada.
  - **Chofer visible (D23):** `ChoferSentado` pone al chofer (el modelo nuevo) en el asiento, con las manos en el volante, que se mueven con la dirección. Es solo figura, sin cuerpo físico, así que nunca sale volando. Los rivales llevan otro igual.
- *Secciones:* 7.1, 7.3, etapa 5.

**D43. Eventos de caos** (15/10/2026, etapa 5)
- *Contexto:* la etapa 5 pide eventos con aviso (topes, bache gigante, animales, bloqueo, lluvia, inspector), carreritas contra rivales y conducción variable. El criterio: al menos un evento memorable por parada, y cada uno se puede apagar para pruebas.
- *Decisión:* `PlanEventos` decide con la semilla de la ruta qué pasa en cada tramo entre paradas: de 1 a 2 eventos, lejos de las paradas, y lluvia y prisa nunca en el mismo tramo (juntas, el chofer siempre se sale de la calle). `GestorEventos` los hace pasar: anuncio con letrero y pitido unos metros antes, inicio y fin. Todo está en `config/eventos.cfg`, con `activo` y `peso` por evento. Los 8 eventos:
  - **Topes:** 4 topes seguidos. El chofer automático no reacciona, porque es un evento puramente físico.
  - **Bache gigante:** 5 m en los dos carriles. El chofer automático frena solo y lo toma a 25 km/h (D3, efecto menor).
  - **Animales:** una vaca y tres gallinas cruzan la calle. El chofer frena y espera a que pasen.
  - **Bloqueo:** una valla de obra cierra la calle. El chofer se detiene, pita y a los 6 s la quitan (D3: se resuelve solo).
  - **Lluvia:** 140 m de calle mojada, con el agarre de las llantas al 60 %, lluvia visible y el cielo nublado.
  - **Inspector:** se anuncia al salir de la parada anterior, para que dé tiempo de cobrar. En la parada revisa y cobra una multa de $12 por cada pasajero a bordo sin pagar; la multa nunca deja el fondo en negativo.
  - **Carrerita (rivales):** aparece la "Ruta 7" (naranja) atrás. El chofer se pone en modo loco y el rival, 20 % más rápido, rebasa por la izquierda. Si gana, se detiene en la siguiente parada y se lleva a la gente que esperaba; si llegamos primero, se sigue de largo. Al irse lejos, desaparece.
  - **Prisa (conducción variable):** el chofer maneja en modo loco 120 m.
- *Para las pruebas:* `Ruta.eventos_activos` fija qué tipos pueden salir; la prueba de la etapa 4 corre sin eventos.
- *Secciones:* 7.1, 7.3, etapa 5.

**D44. Camión más ancho, sentarse y mejor caminado** (17/10/2026, pedido del dueño)
- *Contexto:* el dueño pidió un camión más espacioso con un pasillo de al menos dos personas, una animación al caminar más fluida y que los jugadores también se puedan sentar. Nada de esto estaba en una etapa del plan.
- *Decisión:*
  - **Camión de 3.0 m** (antes 2.5 m): los asientos se pegan a las paredes (`X_ASIENTOS`, x = ±1.03) y el pasillo queda de 1.2 m, donde caben dos cápsulas de 0.54 m lado a lado. Se movieron con él el chofer, el tablero, la puerta, los escalones, el poste, los pasamanos (x = ±0.5), la caja de choque y las ruedas (x = ±1.25). El largo no cambió.
  - **Pasajeros:** van de pie en dos filas (10 lugares, antes 5) y caminan a su asiento por su lado del pasillo. La capacidad sigue en 15 (`config/pasajeros.cfg`).
  - **Sentarse (tecla C, botón Y del mando):** el jugador se sienta en el asiento libre más cercano a menos de `alcance_asiento` (1.2 m, `config/interior.cfg`) y se para con la misma tecla. Usa los mismos asientos que los pasajeros (`GestorPasajeros`), así que nadie le gana el suyo. Sentado no lo mueve nada, igual que a los pasajeros, y puede voltear la cabeza hasta 110° y cobrar a quien alcance.
  - **Recolocar sin aventar nada:** `InteriorCamion.recolocar` saca el cuerpo del espacio y lo vuelve a meter. Si solo se movía, Jolt lo tomaba como un movimiento cinemático rapidísimo y aventaba a 60 m/s lo que estuviera tocando (pasó con el maniquí recargado en un asiento al reiniciar).
  - **Caminado:** el ritmo de los pasos sigue a la velocidad (los pies no patinan), el cuerpo sube y baja como péndulo para que las piernas rígidas no floten, la cadera se mece, los hombros giran contra las piernas, se echa un poco hacia adelante y en reposo respira. Todo entra y sale suavizado.
- *Secciones:* 3, 5.1, 7.2.

**D45. Personajes sin huecos ni grietas** (18/10/2026, pedido del dueño)
- *Contexto:* al revisar los 16 personajes en las poses del juego, todos mostraban el interior negro al levantar un brazo o sentarse: los cortes entre piezas quedaban abiertos. Además, la reducción de Godot (de ~250 000 a ~6 000 triángulos) abría grietas en todas las costuras de la textura (rayones negros en los brazos), la cabeza de los de hombros altos se llevaba los hombros, y el brazo levantado tapaba la cara.
- *Decisión:*
  - **Blender termina los personajes:** `procesar_personajes.bat` busca Blender (o `BLENDER_EXE`). Si lo encuentra, Godot corta las piezas sin reducir y `scripts/herramientas/tapar_cortes.py` las suelda, tapa cada corte con un abanico de triángulos del color de la orilla, las reduce (Blender reduce la malla soldada y no abre grietas) y les copia las normales del modelo completo. Sin Blender se hace como antes. Cada pieza terminada lleva la marca `cortes_tapados` para no volver a comprimir su textura.
  - **Cuello:** en `modelos/personajes.cfg`, `cara_x` (medio ancho de la cara) y `nuca_z` (dónde está la nuca, de lado) para los de hombros altos o encorvados: justo arriba del cuello, lo que queda más afuera que la cara o más atrás que la nuca es torso.
  - **Brazos con profundidad:** el brazo se corta como un cilindro a la profundidad de su mano, no como una rebanada de todo el grueso del cuerpo, así la ropa de los costados se queda en el torso. Los modelos en pose T (el chofer) se cortan como antes.
  - **Pedazos sueltos** que no tocan ninguna pieza (un mechón, un arete) se van con la pieza más cercana.
  - **Sujetarse:** el brazo sube abierto hacia afuera y ya no pasa por enfrente de la cara.
- *Secciones:* 3, 8.

**D46. Caras nítidas: textura propia y contorno sin astillas** (18/10/2026, pedido del dueño)
- *Contexto:* en el juego las caras se veían borrosas y con "pinceladas". Había dos causas: (1) Tripo pinta a 6–9 personajes en una sola hoja de 4096 px con sus pedazos revueltos, así que el recorte de cada personaje era la hoja entera, que se encogía a 1024 px (25 %); además, los bordes de cada pedazo se mezclaban con los vecinos, que muchas veces son de otro personaje, y salían rayas. (2) El contorno de casco invertido se asomaba por las partes hundidas (orejas, boca, bajo la visera) como astillas negras.
- *Decisión:*
  - **Textura propia:** `tapar_cortes.py` acomoda solo los pedazos de cada personaje en una imagen nueva de `tamano_textura` (ahora 2048 px) y copia ahí los colores de la hoja a resolución completa (horneado con Cycles), con 16 px de margen del mismo color. Godot ya no encoge la hoja cuando sigue Blender. Las tapas de los cortes toman el color de su orilla.
  - **Contorno:** `contorno.gdshader` aleja el casco de la cámara (`empuje`, 4 cm en los personajes), así solo asoma en la silueta. El camión y la calle no cambian.
  - **Memoria:** las texturas de los personajes se importan con compresión de video de alta calidad (BPTC) en lugar de sin pérdida: unos 90 MB en lugar de 340 MB para los 16, sin diferencia visible. Un personaje nuevo hay que ponerlo igual (en el editor: Importar → Compress Mode: VRAM Compressed, High Quality).
  - Lo que queda en las caras (manchitas, trazos alrededor de los ojos) viene pintado así por Tripo.
- *Secciones:* 3, 8.
