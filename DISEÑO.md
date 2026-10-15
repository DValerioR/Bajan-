# BAJAN! — Documento de diseño

Nombre provisional del juego: **Bajan!**, con subtítulo en inglés provisional "The Chaotic Microbus Game". Este documento (`DISEÑO.md`) es la fuente de verdad del proyecto. Léelo completo antes de hacer cualquier cosa, mantenlo en la raíz del proyecto y consúltalo al inicio de cada sesión. Si algo se contradice o falta información, no lo inventes en silencio: si es un detalle menor, anótalo en `DECISIONES.md` con tu propuesta y sigue con la opción más sencilla; si es una decisión de diseño grande, pregúntamelo como indica la sección 0.

## 0. Arranque: lo que debes hacer antes de la etapa 0

Las decisiones D1 a D14 de la revisión previa, y las decisiones D15 a D24 que surgieron después, ya están resueltas y aprobadas por mí. El Apéndice las resume y las secciones 1 a 12 ya las incorporan, así que no me las vuelvas a preguntar. Haz esto, en orden:

1. Lee todo el documento. Si encuentras un hueco o una contradicción que no esté cubierta, preséntamelo en un bloque de 2 a 4 preguntas como máximo. Para cada una dame la pregunta, por qué importa y tu recomendación, y deja que yo elija. Si te digo "lo que recomiendes", toma tu recomendación.
2. Si el paso 1 cambió algo, corrige `DISEÑO.md` y agrega la decisión al final de `DECISIONES.md`, que ya existe y registra D1 a D24 con su contexto. Solo archivos de texto en la carpeta de trabajo.
3. El nombre ya está verificado, no hace falta repetirlo ahora. Una búsqueda en la tienda de Steam (15/10/2026) solo mostró "Bajan Ball Z" y su demo, sin ningún juego llamado "Bajan" a secas, y yo comprobé a mano que en itch.io no existe ningún otro juego llamado "Bajan!". Esto no revisa marcas registradas. Volveremos a verificar en la etapa 9.
4. Muéstrame un resumen final de lo que entendiste y espera mi aprobación explícita antes de empezar la etapa 0. No instales nada, no crees el repositorio ni el proyecto de Godot antes de esa aprobación.

## 1. Qué es el juego

Bajan! es un juego cooperativo caótico (friendslop) para 1 a 4 jugadores. Los jugadores trabajan en un microbús urbano mexicano que recorre una ruta con paradas, tratando de juntar dinero mientras todo sale mal: el camión frena y acelera de golpe, los pasajeros salen volando, aparecen topes, baches, animales, bloqueos, camiones rivales e inspectores. Cada partida debe producir clips graciosos de forma accidental. El objetivo comercial es modesto: un juego pequeño, barato de producir, que se entienda en una frase y que sirva para clips en TikTok y Shorts. No se busca profundidad, se busca risa.

La prioridad de diseño, por encima de todo, es que cada sistema falle de forma graciosa en lugar de romperse. Una física exagerada que hace volar a un pasajero por la ventana es una función, no un bug. Un crash o un jugador atrapado dentro de una pared sí es un bug.

El máximo de la v1 es 4 jugadores. Los pasajeros jugables (jugadores 5 a 8) quedan fuera de la v1, pero la arquitectura usa un valor de configuración `MAX_JUGADORES` para poder ampliarlo después.

## 2. Cómo quiero que trabajes

Empieza de cero, pero solo después de cerrar la sección 0 y de tener mi aprobación. No asumas que Godot está instalado. En la primera sesión de desarrollo verifica el sistema (Windows), instala Godot 4.5.x estable o la versión estable más reciente que sea compatible con GodotSteam (revisa la página de GodotSteam antes de elegir), inicializa un repositorio git y crea la estructura de carpetas. Deja dos scripts: `ejecutar.bat`, que abre el editor con el proyecto, y `jugar.bat`, que lanza el juego directamente. Usa GDScript, no C#. Usa Jolt Physics como motor de física 3D si está disponible en la versión elegida, y justifica en `DECISIONES.md` si decides lo contrario.

Trabaja por etapas, en el orden de la sección 12. Al terminar cada etapa, escribe qué quedó funcionando, cómo probarlo a mano (qué teclas, qué escena abrir) y qué quedó pendiente, y haz un commit con un mensaje claro. No avances a la siguiente etapa si los criterios de aceptación de la actual no se cumplen. Antes de dar algo por terminado, ejecútalo: si puedes correr Godot en modo headless para pruebas, hazlo; si no, dime exactamente qué tengo que revisar yo a mano. No des por hecho que algo funciona porque el código parece correcto, sobre todo en física.

Toda la lógica del juego debe estar escrita pensando en multijugador desde el día uno, aunque la red se implemente al final: separa la entrada del jugador (comandos) de la simulación, evita que los nodos de interfaz lean o escriban estado del juego directamente, guarda el estado de la partida en un solo lugar y usa `MAX_JUGADORES` en lugar de números fijos. Los textos visibles nunca van escritos en el código: todo pasa por un sistema de traducción con español como idioma principal e inglés como segundo, desde la primera pantalla.

Todos los números de diseño (penalizaciones, caja chica, cuotas, parámetros de conducción, de bots, de eventos, límite de ragdolls activos, precios de la tiendita) viven en archivos de configuración o de datos separados del código, para poder ajustarlos jugando sin tocar scripts.

## 3. Estilo visual

El estilo es low poly con sombreado toon y contornos gruesos, inspirado en el espíritu visual de los juegos de cel shading tipo The Legend of Zelda: The Wind Waker (colores limpios, formas redondeadas, expresiones exageradas, agua y nubes estilizadas), pero sin copiar ningún diseño, personaje, logotipo ni elemento reconocible de esa franquicia. Los personajes deben ser caricaturescos y algo grotescos: cabezas grandes, narices y mentones exagerados, cuerpos chaparros o muy flacos, ojos expresivos. Lo suficiente para dar risa, nunca para dar asco o incomodidad.

Por ahora todos los modelos se hacen con formas básicas (cubos, cápsulas, esferas, cilindros) dentro del propio proyecto, con materiales de colores planos. El shader toon y el contorno básicos se aplican desde la etapa 1, para que todo se vea coherente aunque sean cubos, y se pulen en la etapa 7. Los personajes deben construirse de modo que luego se puedan sustituir por modelos importados sin reescribir la lógica: una escena de personaje con un esqueleto simple, puntos de agarre y una interfaz clara. Más adelante vendrán modelos generados con IA, así que documenta qué formato y escala esperas (glTF, altura de personaje en metros, ejes y origen).

## 4. El mundo

La ciudad es ficticia pero se siente mexicana, inspirada en Guadalajara y la Ciudad de México. Debe mezclar zonas de contraste, que además sirven como biomas del juego con distintos obstáculos y tipos de pasajeros. Una zona popular con tianguis, puestos de tacos, tendederos, cables enredados, topes y baches. Un centro histórico con calles angostas, plazas, mercados y mucho tráfico. Una zona de lujo con avenidas amplias, plazas comerciales, camionetas caras y pasajeros presumidos, inspirada en lugares como Andares o Polanco pero con nombres, marcas y edificios inventados. Y una zona de cruce con avenidas rápidas, puentes y glorietas. No uses marcas reales, logotipos ni nombres comerciales verdaderos. Los letreros son inventados y graciosos, en español, con versión en inglés cuando aplique.

La ruta se genera distinta cada vez, uniendo tramos de estas zonas. Cada tramo es una pieza prediseñada (calle con sus obstáculos, edificios y paradas posibles, y una curva de ruta que los bots pueden seguir), y el generador las encadena con reglas simples: no repetir la misma zona más de dos veces seguidas, aumentar la dificultad con el avance, garantizar que cada parada sea alcanzable.

## 5. Roles y modos de juego

### 5.1 Roles

Hay cuatro roles en el camión, y el máximo de la v1 es de 4 jugadores. Los puestos que no ocupa un jugador los cubren bots con peor desempeño que un humano.

El **chofer** maneja, usa el claxon y abre la puerta en las paradas. El **cobrador** camina por el pasillo cobrando el pasaje a cada pasajero acercándose a él y usando la acción de cobrar; las monedas caen al suelo si el camión frena o gira mal. El **voceador** cuelga de la puerta y grita la ruta en cada parada para atraer pasajeros: cuando el grito supera un umbral, los pasajeros no jugables se acercan a la puerta, y tiene una barra de aliento que se agota al gritar. Además ayuda a subir a los pasajeros, con el riesgo de resbalarse al ir colgado de la puerta. El **vendedor de dulces** vende dulces a los pasajeros por propinas y pierde mercancía si el camión frena fuerte. Si es un jugador, viaja siempre a bordo para no quedarse sin jugar. Si es un bot, sube solo en algunas paradas. Su mercancía es limitada y se repone gratis en algunas paradas, donde el vendedor jugador puede bajar un momento a reabastecer. Si el camión arranca y lo deja abajo mientras reabastece, el vendedor toma automáticamente un taxi que lo lleva a la siguiente parada, y el equipo paga la penalización del taxi (sección 6.2). No cuenta como reaparecer: no paga esa otra penalización ni puede quedar de espectador por esto. El taxi es solo para este caso: el vendedor que bajó por elección propia a reabastecer.

**Jugadores en tierra (D22).** Cualquier jugador (incluido el vendedor) que se queda en tierra en una parada sin haber bajado por elección propia, por ejemplo porque lo empujaron o se cayó por la puerta, se trata igual que quien sale volando. Reaparece en la siguiente parada pagando la penalización de reaparecer, y queda como espectador si el fondo no alcanza.

Máximo dos acciones concretas por rol. No añadas más sin consultarme.

### 5.2 Bots del interior

Los bots del interior (cobrador, voceador, vendedor) no necesitan navegación compleja: el interior del camión es básicamente un pasillo. Se mueven por una lista fija de puntos de paso (puerta, pasillo, fondo, asientos) con una máquina de estados sencilla: ir a un punto, hacer su acción, volver. Usan el mismo cuerpo y la misma física de personaje que los jugadores, así que reciben los mismos empujones de inercia, se caen y se levantan igual que un humano. Cuando el camión frena o gira fuerte, se agarran del pasamanos más cercano; a veces no alcanzan y se caen, lo cual es parte de su peor desempeño. Sus parámetros (velocidad, tiempo de reacción, probabilidad de fallar) van en el archivo de configuración. Los puntos de paso se definen en la escena del camión y se mueven con él, así que este sistema debe funcionar con el enfoque que salga de la decisión D1 (sección 7.2). El voceador bot grita con la versión de teclado, no con micrófono.

### 5.3 Modos de juego

**Modo normal.** Al empezar, cada jugador elige su rol o selecciona "al azar", y se queda con ese rol toda la partida.

**"Tírame paro"** (en inglés **"Help me with this"**). Los roles se reparten al azar al empezar y rotan en cada parada, como si los jugadores se pidieran ayuda unos a otros.

*Inicio.* Cada jugador empieza con un rol distinto al que tuvo al iniciar su partida anterior en este modo (se guarda en las preferencias locales de cada jugador y cada cliente se lo reporta al anfitrión, que hace el reparto). Sin datos previos, el reparto es completamente al azar. Así nadie empieza siempre como chofer y no hace falta un chofer por defecto. Jugando solo, los bots cubren los roles que no te tocaron, incluido el de chofer.

*Rotación.* No hay teletransporte. La rotación ocurre solo con el camión detenido en una parada, dentro de la ventana de parada (sección 6.0), que se alarga unos segundos por el cambio de puestos. Hay un aviso claro en pantalla de qué rol le toca a cada jugador. Los jugadores y los bots caminan a sus puestos. Los espectadores (sección 6.3) no entran en la rotación. En "Tírame paro", cuando vuelven a entrar, toman el rol que haya quedado libre o cubierto por un bot. En Modo normal recuperan su rol original, que un bot venía cubriendo (D24). El camión no arranca hasta que el asiento del chofer esté ocupado. Si se acaba el tiempo y nadie lo ocupa, los pasajeros se desesperan (gritan, pagan menos o se bajan) y después el bot toma el volante. La rotación no debe poder dejar a un jugador atrapado o fuera de posición.

*Chofer fuera del camión (aplica en cualquier modo).* Nadie cambia de rol. Si el chofer sale volando, el camión sin conductor desacelera poco a poco (no se detiene en seco) y cualquier otro jugador puede sentarse al volante y manejar, sin dejar de tener su rol. Su puesto queda vacío mientras maneja, sin que lo cubra ningún bot. Si nadie toma el volante, los pasajeros se desesperan (gritan, pagan menos o se bajan) y, tras unos segundos, el bot toma el volante. Al llegar a la siguiente parada, si el camión no lo trae su chofer (lo trae otro jugador o el bot), el equipo recibe la penalización "el chofer no entregó el camión" (sección 6). Esta penalización se cobra una sola vez por incidente, en la primera parada a la que llega el camión sin su chofer. Lo que pasa después depende del modo:

- **Modo normal:** el chofer reaparece en esa parada y retoma el volante, y quien lo sustituyó vuelve a su puesto.
- **"Tírame paro" (D21):** el chofer que reaparece entra a la rotación de esa parada, como cualquier otro jugador, y no retoma el volante. La rotación disuelve la sustitución, y el nuevo reparto decide quién maneja.

Si el chofer no puede reaparecer porque está de espectador (sección 6), quien lo sustituyó sigue manejando y un bot cubre el puesto que dejó. En Modo normal sigue así hasta que el chofer regresa y retoma el volante en una parada. En "Tírame paro", la rotación de esa misma parada reparte los puestos entre los jugadores presentes. En ningún caso se vuelve a cobrar la penalización durante ese tiempo.

El bot chofer no puede salir volando: va sujeto al asiento (D23).

## 6. Estructura de la partida y dinero

La partida es una cadena de rutas. Cada ruta tiene un inicio, varias paradas (entre 6 y 10 al principio, definidas por el generador) y un final. Al terminar una ruta se llega a la tiendita de abarrotes, donde se gasta dinero en mejoras y consumibles antes de arrancar la siguiente ruta, con una cuota más alta.

### 6.0 Flujo de pasajeros

Debe sentirse como una ruta de transporte público y no como un viaje a un destino: la gente sube y baja todo el tiempo. Cada pasajero que sube elige al azar una parada de bajada, a pocas paradas de distancia. En cada parada se bajan solo los pasajeros cuyo destino es esa parada (unos cuantos, nunca todos) y se sube una cantidad aleatoria de pasajeros nuevos, que el voceador puede aumentar con su grito. Los pasajeros que no han pagado al bajarse son dinero perdido. La capacidad del camión y los rangos de pasajeros que suben y bajan van en configuración; la capacidad inicial debe respetar el criterio de la etapa 3 (15 pasajeros a bordo).

**Ventana de parada (D20).** Cada parada tiene una ventana de duración configurable, con un temporizador visible. Dentro de ella ocurren:

- el grito del voceador;
- la subida y bajada de pasajeros;
- la rotación de "Tírame paro", para la que la ventana se alarga unos segundos;
- el reabastecimiento del vendedor.

El chofer puede salir antes de que termine la ventana. Si se pasa del tiempo sin salir, los pasajeros se desesperan con la misma mecánica de la sección 5.3 (pagan menos o se bajan). El bot chofer sale al terminar la ventana.

### 6.1 Dinero

El dinero es un **fondo común** del equipo. Cada ruta tiene una **cuota** (la cuenta que se le entrega al dueño del microbús).

La **caja chica** es un valor de configuración `C`; sugiero que sea cuatro veces la penalización de reaparecer, y se ajusta jugando. En la primera ruta el fondo empieza con `C`. En cada ruta siguiente el fondo empieza con el dinero que el equipo guardó de la ruta anterior (lo que quedó después de pagar la cuota y comprar en la tiendita) más una bonificación igual al 50 % de `C`.

La **ganancia de la ruta** es lo que entra durante esa ruta (pasajes, propinas del vendedor) menos las penalizaciones pagadas en ella. La ruta se cumple si la ganancia alcanza la cuota; al cumplirla, la cuota se descuenta del fondo. Como la ganancia de la ruta es al menos la cuota, el fondo después de pagarla nunca es menor que el fondo con el que empezó la ruta, y nunca es negativo; escribe una prueba automática que lo verifique. Si la ganancia no alcanza la cuota, la partida termina.

Las monedas tiradas en el piso del camión las puede recoger cualquiera. Las que salen por la ventana se pierden y no cuentan como ingreso.

### 6.2 Penalizaciones

Todas las penalizaciones se descuentan del fondo, sus valores van en configuración y pueden sumarse en la misma parada:

- **Reaparecer:** un jugador que salió volando, quedó fuera de combate o se quedó en tierra sin haber bajado por elección propia (D22) reaparece en la siguiente parada pagándola. Si el fondo no alcanza, el jugador queda como espectador (sección 6.3).
- **"El chofer no entregó el camión":** sección 5.3, una sola vez por incidente.
- **Bot fuera del camión:** si un bot del interior sale volando (el bot chofer no puede, D23), el equipo paga la mitad del pasaje y el bot vuelve a subir en la siguiente parada. Mientras tanto su puesto queda vacío.
- **Taxi del vendedor:** si el camión deja abajo al vendedor jugador mientras reabastece por elección propia, el equipo paga el taxi que lo lleva a la siguiente parada (sección 5.1). Si se quedó abajo por cualquier otra razón, aplica la de reaparecer.

Excepto la de reaparecer, ninguna penalización puede dejar el fondo en negativo: si no alcanza, el fondo queda en 0 y el resto no se cobra. Así se mantiene la garantía de la sección 6.1. Súmalas con cuidado al ajustar el juego, porque juntas pueden ser muy duras.

### 6.3 Espectadores

Si al reaparecer el fondo no alcanza para pagar la penalización, el jugador no reaparece: se queda como espectador. Un espectador tiene una cámara libre que alterna entre sus compañeros, no puede tocar nada, puede mandar emotes o texto y ve cuánto dinero falta para volver a entrar. En cada parada siguiente se revisa el fondo, y en cuanto alcanza se descuenta la penalización y el jugador reaparece en esa parada. Si todos los jugadores quedan como espectadores, la ruta termina como fallida y la partida termina.

El objetivo del ajuste es que ser espectador sea raro y corto; la caja chica y la bonificación del 50 % existen para eso. Si en las pruebas resulta frecuente, dímelo en lugar de resolverlo por tu cuenta.

### 6.4 Fin de la partida

La partida termina cuando una ruta se cierra sin alcanzar la cuota, cuando el camión queda destruido o cuando todos los jugadores quedan como espectadores. Al final se muestra el récord de rutas completadas y el dinero total.

### 6.5 La tiendita

La tiendita de abarrotes vende mejoras y consumibles graciosos: veladoras de la Virgen que protegen un poco al camión, refrescos que aceleran al cobrador, un claxon más escandaloso, llantas con mejor agarre, cinta adhesiva para pegar partes del camión, un amortiguador usado, una estampita de San Judas, etc. Cada mejora debe cambiar algo perceptible en el juego, no solo un número. Define un catálogo inicial de 8 a 10 artículos en un archivo de datos separado del código. Algunas mejoras reparan o protegen el camión (sección 7.4).

## 7. Conducción, física y caos

### 7.1 Conducción

El camión usa una conducción arcade, exagerada y un poco difícil de controlar, pero nunca imposible. El comportamiento del chofer cambia durante la ruta: hay momentos de "carrerita" contra otros camiones en los que el chofer es empujado a acelerar y frenar bruscamente, tramos de calle mojada, baches que desvían el volante y frenazos inesperados de tráfico. Estos cambios deben ser eventos con inicio y fin, claramente anunciados con una señal sonora o visual corta, no ruido aleatorio permanente. Todos los parámetros de conducción (aceleración, frenado, agarre, sensibilidad de volante, intensidad de los eventos) viven en un archivo de configuración fácil de ajustar.

### 7.2 El interior del camión (decisiones D1 y D2)

Dentro del camión, los jugadores caminan con control de personaje y reciben empujones por inercia cuando el camión acelera, frena o gira. Esta es la parte técnicamente más delicada del proyecto y debe resolverse en la etapa 2, antes de agregar cualquier otra cosa.

El personaje (`CharacterBody3D`) se mueve naturalmente en coordenadas locales del camión, pero los ragdolls, las monedas y los objetos lanzados son cuerpos físicos (`RigidBody3D`) que viven en el mundo. Hay que elegir un solo enfoque para todo lo que está dentro del camión y definir qué pasa al cruzar la frontera entre interior y mundo: al agarrar un objeto, al lanzarlo, o cuando algo o alguien sale volando por una ventana o la puerta.

Antes de construir sobre un enfoque, haz un prototipo mínimo de dos o tres opciones (por ejemplo: un interior físico separado que copia el movimiento del camión, todo en el mundo con fuerzas de compensación, o una combinación de ambos) y muéstrame cómo probar cada una. Elegimos juntos. Documenta la decisión en `DECISIONES.md`.

En red, cada jugador tiene autoridad sobre su propio movimiento dentro del camión (se siente inmediato), con validación simple del anfitrión. El anfitrión mantiene la autoridad sobre el camión, los eventos, los empujones y los ragdolls.

### 7.3 Bot chofer y eventos (decisión D3)

El bot chofer es de línea fija: sigue la curva de la ruta, frena en las paradas y arranca al terminar la ventana de parada (sección 6.0). Va sujeto al asiento y no puede salir volando del camión (D23). Maneja mal a propósito: frenazos y acelerones al azar, se pasa un poco de la parada, toma las curvas muy abiertas. Controla el mismo camión con los mismos controles que un jugador (acelerar, frenar, girar), sin trucos de animación, para que la inercia del interior sea real. Ese mismo conductor se reutiliza en los camiones rivales. En la v1 no esquiva obstáculos ni reacciona a eventos, por lo que mientras maneja un bot los eventos que exigen reaccionar (bloqueo, inspector, bache gigante y similares) se simplifican: el bot frena solo ante ellos, el evento se resuelve de forma automática y su efecto es menor. Los eventos puramente físicos (topes, calle mojada) siguen igual. El bot es el respaldo para cualquier puesto de chofer vacío.

### 7.4 Daño del camión (decisión D5)

La integridad del camión es una barra, y es la mecánica real. Además hay piezas visibles que se caen (puertas, espejos, defensa) como efecto cómico, sin afectar el cálculo al inicio. Lo dañan los choques fuertes, los baches grandes y los rivales. Las mejoras de la tiendita lo reparan o protegen. Si la integridad llega a cero, la partida termina.

### 7.5 Pasajeros y ragdolls (decisión D4)

Los pasajeros tranquilos o sentados son cuerpos simples o animados. El ragdoll se activa solo con un golpe fuerte y vuelven al estado simple después. Hay un máximo de ragdolls activos al mismo tiempo, con un valor inicial pequeño y ajustable desde el archivo de configuración.

### 7.6 Objetos y golpes

Los jugadores pueden agarrar y lanzar objetos (monedas, dulces, bolsas, pasajeros), empujar y golpear. Los golpes tienen efecto físico visible pero no son letales por sí mismos: sirven para sacar a alguien del paso o para hacer volar a un pasajero.

## 8. Ragdoll y desmembramiento

Los personajes y los pasajeros usan ragdoll con articulaciones, y sus extremidades se pueden desprender cuando la fuerza supera un umbral. La v1 sale sin sangre ni fluidos: las extremidades se desprenden como piezas de muñeco o de caricatura, y el efecto de impacto es un golpe seco con estrellitas o humo, nunca rojo. Esto aplica a pasajeros y a jugadores; a los jugadores se les restauran las extremidades al reaparecer. El desprendimiento es solo un efecto cómico y no afecta el juego. El ragdoll de pasajeros y jugadores llega en la etapa 3 (en la etapa 2 el jugador solo tropieza y cae de forma simple) y el desprendimiento en la etapa 7.

El Modo Streamer queda pospuesto porque no hay sangre que desactivar; se retoma si algún día se agrega la sangre como opción.

Evita absolutamente cualquier contenido sexual o referencia a abuso sexual, en texto, imágenes, chistes o animaciones. Evita también humor basado en burlas a grupos de personas por raza, discapacidad o religión. El humor es de situaciones físicas y de personajes exagerados, con diálogo cómico en texto.

## 9. Cámara y control

La perspectiva principal es primera persona. Existe también una opción de tercera persona para todos los roles, excepto el chofer, que solo puede manejar en primera persona (esto incluye a quien sustituya al chofer). Soporta teclado y ratón primero, y deja la entrada preparada para mando: todas las acciones deben pasar por el sistema de acciones de Godot, nunca leer teclas directo. Configura los controles desde el menú de ajustes.

## 10. Audio y texto

La música será original y generada con IA de licencia comercial, en loops sin costura. Mientras tanto, usa música de relleno silenciosa o tonos simples y deja una carpeta `audio/musica/` con un sistema que cargue y mezcle pistas por zona (zona popular, centro, zona de lujo, cruce, tiendita, menú), con transición suave. La radio del camión debe poder subir y bajar de volumen como mecánica del juego, y en un futuro tapar el chat de voz por proximidad, que queda fuera de la primera versión.

Los personajes no tienen voz. Hablan con globos de texto y un sonido corto de murmullo por letra o por sílaba, parecido al estilo de Undertale, con un tono distinto por personaje o por tipo de pasajero. Genera los murmullos con sonidos sintéticos simples dentro del proyecto. Los efectos de sonido (claxon, frenazo, golpe, monedas) también deben ser placeholders generados o sencillos, con una carpeta organizada para sustituirlos después.

### 10.1 El grito del voceador

El grito se implementa en dos pasos dentro de la etapa 6. Primero, por teclado o mando: mantener una acción para gritar, con la misma barra de aliento. Esta es la versión que usan los bots voceadores y la que basta para cumplir el criterio de las sub-etapas 6A a 6C. Segundo, como sub-etapa 6D, con el micrófono real del jugador.

Con el micrófono, el juego solo mide el volumen: no graba ni transmite nada, y esto se debe decir en la página de Steam. Incluye una pantalla de calibración que mide el volumen normal y el grito del jugador para fijar el umbral. Godot no trae cancelación de eco, así que no prometas filtrar el sonido del juego: la protección contra falsos disparos es recomendar audífonos, calibrar bien el umbral y bajar el volumen del juego (radio, claxon, música) durante la ventana de gritar en cada parada. La opción de teclado sigue disponible siempre, para quien no tenga micrófono o no pueda gritar.

## 11. Multijugador y Steam

La red se implementa en la etapa 8, no antes, pero la arquitectura la espera desde el principio. Usa la API de multijugador de alto nivel de Godot. Primero con ENet para pruebas locales y luego con GodotSteam (GDExtension más MultiplayerPeer de Steam) para lobbies de Steam. El anfitrión simula la física del camión, los pasajeros y los eventos, y los clientes reciben el estado, con la excepción del movimiento propio de cada jugador dentro del camión (sección 7.2). Los ragdolls son lo más costoso de sincronizar: simúlalos solo en el anfitrión y envía instantáneas a menor frecuencia, interpolando en los clientes. La v1 llega a un máximo de 4 jugadores; no hace falta probar con más, pero no pongas números fijos en el código.

La primera versión es solo para Windows y Steam. El juego se muestra en español e inglés. Steam exige declarar el uso de IA generativa en el contenido (música, modelos, textos) al publicar, y debe llevarse un registro en `CREDITOS_Y_LICENCIAS.md` de cada recurso externo o generado con IA, su fuente y su licencia.

## 12. Etapas y criterios de aceptación

**Etapa 0: preparación.** Solo después de mi aprobación de la sección 0. Godot instalado, repositorio, estructura de carpetas, `README.md`, `DISEÑO.md` (este documento), `DECISIONES.md`, `CREDITOS_Y_LICENCIAS.md`, `ejecutar.bat` y `jugar.bat`, sistema de traducción funcionando con dos idiomas, escena principal que abre sin errores. Criterio: ejecuto `ejecutar.bat` y veo una escena de prueba con un texto traducido que puedo cambiar entre español e inglés.

**Etapa 1: el camión.** Camión de formas básicas sobre una calle de prueba con topes, baches y curvas, conducción arcade en primera persona con parámetros ajustables, y el shader toon y contorno básicos. Criterio: se puede manejar sin voltearse en condiciones normales, se siente exagerado y divertido, y mis amigos y yo podemos reírnos solo de conducir.

**Etapa 2: el interior.** Primero el prototipo de dos o tres enfoques de la sección 7.2, elegidos juntos. Después, un personaje que camina dentro del camión en movimiento, con empujones por inercia y sin salir disparado por errores de física, y un maniquí físico de prueba para agarrar, soltar, lanzar y empujar (los pasajeros reales llegan en la etapa 3). El jugador todavía no usa ragdoll: cuando el caos lo tumba, tropieza y cae de forma simple, y se levanta. Criterio: puedo caminar de la puerta al fondo con el camión acelerando, frenando y girando, y la única razón por la que me caigo es por el caos y no por un fallo del sistema. Esta etapa decide si el proyecto es viable. Si no se cumple, detente y dime qué enfoque alternativo propones.

**Etapa 3: pasajeros.** Pasajeros no jugables con ragdoll (con el límite de ragdolls activos) que suben y bajen en paradas, se agarran de los pasamanos, salen volando por ventanas y puertas, y se pueden recoger. El mismo sistema de ragdoll se aplica al personaje del jugador, sustituyendo la caída simple de la etapa 2: un golpe fuerte lo convierte en ragdoll y después se levanta. Criterio: con 15 pasajeros a bordo, el juego se mantiene a una tasa de cuadros estable en una computadora de gama media.

**Etapa 4: dinero y ruta.** Cobro de pasaje, monedas que caen, fondo común con caja chica y bonificación del 50 %, cuota por ruta y su pago, flujo de pasajeros y ventana de parada con temporizador de la sección 6.0, reaparecer en la siguiente parada pagando la penalización (en esta etapa todavía no hay espectadores, así que si el fondo no alcanza, el jugador reaparece sin pagar), generador de ruta con paradas y tramos de distintas zonas, pantalla de resultado de ruta. Criterio: puedo completar una ruta de principio a fin, ganar o perder por cuota, el generador produce rutas diferentes, y la prueba automática del fondo (sección 6.1) pasa.

**Etapa 5: eventos y rivales.** Eventos de caos con aviso (topes, bache gigante, animales, bloqueo, lluvia, inspector), camiones rivales que hacen carrerita, conducción variable del chofer, y el conductor de línea fija de la sección 7.3, que usan los rivales y que después usará el bot chofer (sujeto al asiento, sin poder salir volando). Criterio: en una ruta pasa al menos un evento memorable por parada, y cada uno se puede desactivar en configuración para pruebas.

**Etapa 6A: roles y bots del interior.** Los cuatro roles con sus acciones, los bots del interior y el bot chofer, y el grito del voceador por teclado. Criterio: puedo elegir cualquier rol, los bots cubren los demás, y se completa una ruta completa en esa configuración.

**Etapa 6B: modos, sustitución de chofer y espectadores.** Modo normal y "Tírame paro" con rotación en cada parada (sin teletransporte), la sustitución del chofer descrita en la sección 5.3 (incluida la disolución por rotación de D21), las penalizaciones de la sección 6.2 (chofer, bot fuera del camión, taxi del vendedor), los jugadores en tierra de D22, y el estado de espectador con el regreso al rol original en Modo normal (D24). Es la etapa más cargada; si conviene dividirla más, propónmelo antes de empezarla (sección 13). Criterio: en "Tírame paro" los puestos rotan en cada parada y el camión no arranca sin chofer; si el chofer sale volando, otro jugador o el bot toma el volante y todo se resuelve en la parada siguiente; puedo provocar el estado de espectador y volver a entrar cuando alcanza el fondo.

**Etapa 6C: tiendita.** Tiendita de abarrotes con catálogo de datos y compras que cambian el juego. Criterio: puedo jugar solo con bots y terminar tres rutas seguidas en ambos modos.

**Etapa 6D: micrófono.** El grito con el micrófono real, con pantalla de calibración y bajada de volumen del juego en la ventana de gritar, y la opción de teclado siempre disponible. Criterio: gritando al micrófono los pasajeros se acercan a la puerta, no se activa solo con el sonido del juego con audífonos puestos, y sin micrófono todo funciona con el teclado.

**Etapa 7: estilo, ciudad y pulido.** Pulido del shader toon y del contorno, zonas de ciudad con identidad visual distinta, letreros graciosos bilingües, desprendimiento de extremidades sin sangre, menús, ajustes, música y sonidos placeholder en su sistema, globos de texto con murmullos. Criterio: una captura de pantalla de cualquier zona se ve coherente y con personalidad aunque todo sean formas básicas.

**Etapa 8: multijugador.** ENet local, luego GodotSteam con lobbies. 4 jugadores en la misma partida. Criterio: cuatro instancias (o cuatro personas) completan una ruta en conjunto sin desincronizaciones graves, y la física del camión se ve aceptable en los clientes.

**Etapa 9: preparación para Steam.** Exportación a Windows, configuración de Steamworks básica, logros simples, página de Steam (textos en español e inglés, con la nota sobre el uso del micrófono), registro de licencias e IA actualizado, revisión del cuestionario de contenido de Steam, y nueva verificación del nombre en Steam e itch.io con el subtítulo definitivo (en octubre de 2026 no había ningún otro "Bajan!" en ninguno de los dos). Criterio: una compilación instalable que se ejecuta en una máquina limpia.

## 13. Qué no hacer

No copies personajes, música, logotipos ni diseños de juegos o franquicias existentes. No uses música ni sonidos con derechos. No pongas texto visible dentro del código. No añadas funciones fuera de este documento sin anotarlas primero en `DECISIONES.md`. No hagas una arquitectura gigante: el proyecto es pequeño y debe poder terminarse. Si dudas entre dos opciones menores, elige la más simple y sigue; las decisiones de diseño grandes me las preguntas.

**Regla de complejidad.** Las reglas de borde ya son muchas. Si una regla de borde cuesta mucho más que las demás en implementarse, o no se puede probar de forma sencilla, simplifícala o déjala para después de que el núcleo sea divertido, y avísame con tu propuesta. El núcleo es conducir, caminar dentro del camión, los pasajeros, el cobro y la ruta. La etapa 6B es la más cargada: si crees que debe dividirse más, propónmelo antes de empezar esa etapa.

## Apéndice: decisiones resueltas

D1: se prototipan dos o tres enfoques para el interior del camión al inicio de la etapa 2 y se elige juntos. D2: cada jugador tiene autoridad sobre su movimiento interior, el anfitrión sobre lo demás. D3: bot chofer de línea fija que maneja mal a propósito, bots del interior por puntos de paso, eventos simplificados cuando maneja el bot. D4: pasajeros simples con ragdoll solo ante golpes fuertes y tope de ragdolls activos. D5: barra de integridad más piezas que se caen como efecto cómico. D6: ragdoll en la etapa 3, desprendimiento en la 7, aplica a pasajeros y jugadores. D7: maniquí de prueba en la etapa 2. D8: toon básico desde la etapa 1, pulido en la 7. D9: voceador (grito por teclado, luego micrófono) y vendedor. D10: "Tírame paro" sin teletransporte, rotación en paradas, sustitución del chofer. D11: fondo común, monedas del piso para cualquiera, monedas por la ventana se pierden, espectador si el fondo no alcanza. D12: sin jugadores 5 a 8 en la v1. D13: nombre "Bajan!" con subtítulo, v1 sin sangre, Modo Streamer pospuesto. D14: `ejecutar.bat` y `jugar.bat`.

D15: caja chica en la primera ruta; en las siguientes, lo guardado más el 50 % de la caja inicial; la cuota se mide contra la ganancia de la ruta y se paga del fondo. D16: el espectador tiene cámara libre, emotes y texto, y ve cuánto falta para volver. D17: la etapa 6 se divide en 6A, 6B, 6C y 6D. D18 (valores por defecto que el dueño no objetó): la mercancía del vendedor es limitada y se repone gratis en algunas paradas; si el chofer no puede volver por ser espectador, su sustituto sigue manejando y un bot cubre el puesto que dejó; las penalizaciones van en configuración; en "Tírame paro" el anfitrión reparte los roles con el último rol que reporta cada jugador.

D19:
- **Penalizaciones y fondo:** salvo la de reaparecer, ninguna penalización deja el fondo en negativo; si no alcanza, queda en 0.
- **Chofer:** "el chofer no entregó el camión" se cobra una vez por incidente.
- **Bots:** un bot que sale volando cuesta la mitad del pasaje y vuelve a subir en la siguiente parada.
- **Rotación:** los espectadores no entran en la rotación de "Tírame paro" y al volver toman el rol libre.
- **Vendedor:** si el camión lo deja abajo, toma un taxi automático a la siguiente parada y el equipo paga el taxi.
- **Pasajeros:** cada uno tiene una parada de destino; en cada parada bajan solo algunos y sube una cantidad aleatoria.
- **Jugando solo:** quedar de espectador termina la partida (se acepta como está).
- **Etapa 4:** sin espectadores todavía; si el fondo no alcanza, se reaparece sin pagar.
- **Ragdoll del jugador:** llega en la etapa 3 junto con el de los pasajeros; en la etapa 2 solo hay caída simple.

D20 a D24 tienen prioridad sobre cualquier texto previo que las contradiga:

- **D20. Ventana de parada:** dura un tiempo configurable y tiene temporizador visible. En ella ocurren el grito, la subida y bajada de pasajeros, la rotación (con unos segundos extra) y el reabastecimiento. El chofer puede salir antes; si se pasa del tiempo, los pasajeros se desesperan. El bot chofer sale al terminar la ventana. Etapa 4.
- **D21. Chofer reaparecido en "Tírame paro":** entra a la rotación de esa parada y no retoma el volante, porque la rotación disuelve la sustitución. En Modo normal sí lo retoma. La penalización se cobra una vez por incidente. Etapa 6B.
- **D22. Jugadores en tierra:** quien se queda en tierra sin haber bajado por elección propia se trata como si hubiera salido volando: penalización de reaparecer, o espectador si el fondo no alcanza. El taxi es solo para el vendedor que baja a reabastecer por elección propia. Etapa 6B.
- **D23. Bot chofer:** va sujeto al asiento y no puede salir volando. Etapa 5.
- **D24. Espectador en Modo normal:** al volver recupera su rol original, que cubría un bot. En "Tírame paro" toma el rol libre o cubierto por un bot. Etapa 6B.
- **Regla de complejidad:** agregada a la sección 13.
- **Nombre:** el dueño comprobó a mano que en itch.io no existe otro juego llamado "Bajan!".
