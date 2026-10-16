# Bajan!

Juego cooperativo caótico de 1 a 4 jugadores en un microbús urbano mexicano. Hecho en Godot 4.7.2 con GDScript y Jolt Physics.

- Diseño completo: [`DISEÑO.md`](DISEÑO.md)
- Registro de decisiones: [`DECISIONES.md`](DECISIONES.md)
- Recursos externos y licencias: [`CREDITOS_Y_LICENCIAS.md`](CREDITOS_Y_LICENCIAS.md)

## Instalación

Godot no se guarda en el repositorio. Para preparar una copia nueva:

1. Descarga **Godot 4.7.2 estable, versión estándar** (no la .NET/mono) para Windows de 64 bits desde https://godotengine.org/download/archive/4.7.2-stable/
2. Descomprime los dos ejecutables (`Godot_v4.7.2-stable_win64.exe` y `Godot_v4.7.2-stable_win64_console.exe`) en `herramientas/godot/`.

Si se cambia de versión de Godot, hay que actualizar la ruta en los tres `.bat` y registrar el cambio en `DECISIONES.md`.

## Cómo usarlo

| Script | Qué hace |
|---|---|
| `ejecutar.bat` | Abre el proyecto en el editor de Godot. |
| `jugar.bat` | Lanza el juego directamente (la primera vez importa los recursos). |
| `pruebas.bat` | Corre las pruebas automáticas sin ventana. Sale con código 0 si todo pasa. |
| `procesar_personajes.bat` | Convierte los modelos originales de `modelos/fuentes/` (no están en git) en personajes de muñeco por piezas: `modelos/personajes/<nombre>.glb`. No toca los `.glb` que ya existen; `procesar_personajes.bat --forzar [nombre]` los regenera. |

Herramientas de desarrollo (se abren desde el editor o con Godot por línea de comandos; no son pruebas automáticas):

- `pruebas/captura.tscn`: maneja el camión y guarda capturas de pantalla desde la vista del chofer y desde cámaras externas. Si no se le pasa una carpeta, las guarda en `user://capturas`.
- `pruebas/experimento_topes.tscn`: pasa el camión sobre un tope a 30, 50 y 70 km/h con varios valores de `patada_topes` y reporta el brinco.
- `pruebas/captura_interior.tscn`: capturas desde el jugador dentro del camión (`-- <carpeta>`).
- `pruebas/vista_personajes.tscn`: los 16 personajes en fila, con las piezas coloreadas (`piezas`), con textura o doblando articulaciones (`pose`).
- `pruebas/vista_modelos.tscn`: captura de frente de un modelo importado.
- `pruebas/captura_ventana.tscn`: llena el camión, avienta a un pasajero y toma capturas desde afuera.
- `pruebas/experimento_rendimiento.tscn`: tiempo por cuadro con 0, 5 y 15 pasajeros; sin `--headless` mide cuadros por segundo con gráficos (`--gpu-index 1` usa la otra GPU).
- `pruebas/experimento_ragdoll.tscn`: suelta un ragdoll en el aire y reporta cómo caen sus piezas.
- `pruebas/captura_ruta.tscn`: genera una ruta (`-- <carpeta> [semilla]`), deja que el chofer automático la maneje a velocidad ×3 y toma una vista aérea y capturas siguiendo al camión, con la zona en el nombre del archivo.

## Estructura

| Carpeta | Contenido |
|---|---|
| `audio/musica/`, `audio/efectos/`, `audio/murmullos/` | Audio por tipo (por ahora vacío; ver DISEÑO.md, sección 10). |
| `config/` | Números de diseño: `juego.cfg` (jugadores, idiomas), `conduccion.cfg` (manejo del camión), `calle_prueba.cfg` (trazado, topes, baches y paradas), `interior.cfg` (caminar adentro, ragdolls, chofer automático), `pasajeros.cfg`, `partida.cfg` (dinero, cobro, paradas), `tramos.cfg` (tramos para generar rutas), `eventos.cfg` (eventos de caos). Nunca van en los scripts. |
| `escenas/` | Escenas: `principal.tscn` (menú de pruebas, escena de arranque), `camion/`, `calle_prueba/`, `ruta/` (una ruta completa), `ui/`. |
| `scripts/autoload/` | Nodos globales: `Config` (lee `config/`, F9 recarga), `Preferencias` (idioma y ajustes locales del jugador) y `Juego` (estado de la partida: dinero y número de ruta). |
| `scripts/camion/` | Simulación del camión (`camion.gd`), comandos de manejo, entrada del jugador, cámara del chofer y carrocería de formas básicas. |
| `scripts/mundo/`, `scripts/estilo/`, `scripts/audio/` | Calle (circuito de prueba y rutas generadas), generador de rutas, conversión al estilo toon y sonidos generados en código. |
| `scripts/partida/`, `scripts/roles/` | Dinero y parámetros de la partida; el cobrador y el chofer sentado. |
| `scripts/eventos/` | Plan de eventos de cada ruta, el gestor que los hace pasar y su utilería (animales, valla, lluvia, inspector). |
| `materiales/` | Shaders del estilo toon y del contorno. |
| `modelos/` | `personajes/` (16 personajes procesados), `personajes.cfg` (cómo se procesan) y `fuentes/` (originales de Tripo, fuera de git). Formato y escala en `DECISIONES.md`, D33 y D34. |
| `scripts/personajes/`, `scripts/interior/`, `scripts/objetos/`, `scripts/pasajeros/` | Personaje (figura, cuerpo, ragdoll), interior del camión (inercia y espacio de física propio), objetos sueltos y pasajeros. |
| `traducciones/` | `textos.csv` con todas las cadenas visibles en español (`es`) e inglés (`en`). |
| `pruebas/` | Escenas de prueba automática que corre `pruebas.bat`. |
| `herramientas/` | Ejecutables de Godot (ignorados por git y por Godot). |

## Editar personajes en Blender

Cada personaje es `modelos/personajes/<nombre>.glb`, con 6 objetos: `Cabeza`, `Torso`, `BrazoIzquierdo`, `BrazoDerecho`, `PiernaIzquierda` y `PiernaDerecha`. El origen de cada uno está en su articulación (cuello, cadera, hombros); es el punto sobre el que gira.

1. En Blender: **Archivo → Importar → glTF 2.0**, y abre el `.glb`.
2. Edita lo que quieras (forma, textura, proporciones). Conserva los **nombres** de los 6 objetos; un sufijo como `.001` no importa. Si mueves una articulación, mueve también el **origen** del objeto.
3. **Archivo → Exportar → glTF 2.0**, formato **glTF Binary (.glb)**, con "+Y Up" activado (viene así por defecto), encima del mismo archivo.
4. Al abrir Godot, se reimporta solo. La estatura, el cuello, la cadera y las manos se recalculan con las piezas.

No corras `procesar_personajes.bat --forzar` con ese personaje, o regresa a la versión original.

Para cambiar un personaje por un modelo suelto de Tripo (como el chofer): copia el `.glb` original a `modelos/fuentes/`, agrega en `modelos/personajes.cfg` una sección con el archivo y la `altura`, y otra con sus medidas (con `brazos_caidos` si viene en pose T), y corre `procesar_personajes.bat --forzar <nombre>`. Ver D41.

## Reglas rápidas

- **Textos visibles:** se agrega una clave en `traducciones/textos.csv` y se usa la clave en el nodo o con `tr()`. Nunca se escribe el texto directo en el código.
- **Números de diseño:** van en `config/`.
- **Entrada:** siempre mediante acciones del Input Map (Proyecto → Configuración del proyecto → Mapa de entrada), nunca leyendo teclas directo.
- **Etapas:** se trabaja por las etapas de `DISEÑO.md`, sección 12, con un commit al cerrar cada una.

## Estado

**Etapa 0 (preparación): completa.** En el menú de pruebas, el botón o la tecla **L** (en mando, Back/Select) cambia entre español e inglés, y el idioma elegido se recuerda.

**Etapa 1 (el camión): completa.** Con `jugar.bat`, en el menú elige **Manejar en la calle de prueba**.

| Control | Teclado | Mando |
|---|---|---|
| Acelerar | W / ↑ | Gatillo derecho |
| Frenar (parado = reversa) | S / ↓ | Gatillo izquierdo |
| Volante | A / D o ← / → | Stick izquierdo |
| Claxon | Espacio / H | A |
| Enderezar el camión | R | Y |
| Mirar alrededor | Ratón | Stick derecho |
| Recargar `config/conduccion.cfg` | F9 | — |
| Volver al menú | Esc | Start |

Para ajustar el manejo: con el juego abierto, edita `config/conduccion.cfg`, guarda y presiona F9.

**Etapa 2 (el interior): completa.** En el menú, **Caminar dentro del camión**. Un chofer automático maneja por la calle de prueba mientras caminas adentro; puedes bajar por la puerta (con el camión parado o en marcha) y volver a subir por los escalones.

| Control | Teclado y ratón | Mando |
|---|---|---|
| Caminar | WASD | Stick izquierdo |
| Mirar | Ratón | Stick derecho |
| Saltar | Espacio | A |
| Sujetarse del pasamanos (mantener) | Shift o clic derecho | LB |
| Agarrar o soltar | E | X |
| Lanzar lo que cargas, o empujar | Clic izquierdo | RB |
| Chofer: parado, tranquilo, normal, loco | 1, 2, 3, 4 | — |
| Volver a la puerta | R | Y |

Hay un maniquí, bolsas y monedas para agarrar y lanzar. Los empujones, el tropiezo y el pasamanos se ajustan en `config/interior.cfg` (F9 recarga).

**Etapa 3 (pasajeros): completa.** En la misma escena, el chofer automático se detiene en las 5 paradas (postes azules con letrero); los pasajeros que esperan suben, se sientan o van de pie sujetos, y bajan en su parada. Con un frenazo fuerte, quien va de pie sin sujetarse cae como ragdoll (también tú), y un empujón o algo que vuela puede sacar a alguien por la puerta o una ventana; el que cae a la calle se pierde. Las piezas de un ragdoll se pueden agarrar (E) y aventar. Los pasajeros se ajustan en `config/pasajeros.cfg` y los ragdolls en `config/interior.cfg` (sección `[ragdoll]`).

**Etapa 4 (una ruta completa): completa.** En el menú, **Jugar una ruta**. Cada ruta se arma distinta con tramos de cuatro zonas (popular, centro, lujo y cruces) y tiene de 6 a 10 paradas. El chofer automático maneja y se detiene en cada parada. Tú eres el cobrador:

- Ponte frente a cada pasajero y cóbrale con **F** (mando: **B**). Los que ya pagaron llevan "$".
- Lo cobrado va en tu morral y se entrega solo al fondo en cada parada. Si tropiezas, se te riega una parte, y si te caes, todo. Recoge las monedas caminando sobre ellas antes de que se pierdan.
- Si te quedas abajo, reapareces en la siguiente parada pagando una multa.
- En la terminal se cierra la ruta: si llegaste a la cuota, sigues a la siguiente ruta (con una cuota más alta). Si no, se acaba la partida.

Los números del dinero, el cobro y la ventana de parada están en `config/partida.cfg`, y los tramos de calle en `config/tramos.cfg` (F9 recarga).

**Etapa 5 (eventos y rivales): en revisión.** En **Jugar una ruta**, el chofer (ahora se ve sentado al volante) maneja mal a propósito y en cada tramo entre paradas pasa al menos un evento, anunciado con un letrero y un pitido:

| Evento | Qué pasa |
|---|---|
| Tope tras tope | Cuatro topes seguidos. |
| Bache gigante | Un hoyo en los dos carriles; el chofer frena un poco. |
| Animales | Una vaca y unas gallinas cruzan; el chofer frena en seco y espera. |
| Calle cerrada | Una valla de obra; el chofer espera, pita y la quitan. |
| Aguacero | Calle mojada: el camión derrapa. |
| Inspector | En la siguiente parada revisa y multa por cada pasajero sin pagar. ¡Cóbrales antes! |
| Carrerita | La Ruta 7 (naranja) aparece atrás; si te rebasa, te gana la parada y se lleva a la gente. |
| Prisa | El chofer maneja como loco un rato. |

Cada evento se puede apagar en `config/eventos.cfg` (`activo=false`) y ahí mismo se ajusta qué tan seguido sale y qué tan fuerte es; los cambios se aplican desde la siguiente ruta.
