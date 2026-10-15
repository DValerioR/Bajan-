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

## Estructura

| Carpeta | Contenido |
|---|---|
| `audio/musica/`, `audio/efectos/`, `audio/murmullos/` | Audio por tipo (por ahora vacío; ver DISEÑO.md, sección 10). |
| `config/` | Números de diseño (`juego.cfg`): jugadores, idiomas y, más adelante, conducción, dinero, bots, etc. Nunca van en los scripts. |
| `escenas/` | Escenas del juego. `principal.tscn` es la escena de arranque. |
| `scripts/autoload/` | Nodos globales: `Config` (lee `config/juego.cfg`) y `Preferencias` (idioma y ajustes locales del jugador). |
| `modelos/`, `materiales/` | Modelos y materiales (por ahora vacíos). |
| `traducciones/` | `textos.csv` con todas las cadenas visibles en español (`es`) e inglés (`en`). |
| `pruebas/` | Escenas de prueba automática que corre `pruebas.bat`. |
| `herramientas/` | Ejecutables de Godot (ignorados por git y por Godot). |

## Reglas rápidas

- **Textos visibles:** se agrega una clave en `traducciones/textos.csv` y se usa la clave en el nodo o con `tr()`. Nunca se escribe el texto directo en el código.
- **Números de diseño:** van en `config/`.
- **Entrada:** siempre mediante acciones del Input Map (Proyecto → Configuración del proyecto → Mapa de entrada), nunca leyendo teclas directo.
- **Etapas:** se trabaja por las etapas de `DISEÑO.md`, sección 12, con un commit al cerrar cada una.

## Estado

**Etapa 0 (preparación): completa.** Para probarla, ejecuta `ejecutar.bat` y luego F5 en el editor, o `jugar.bat`. Verás la escena de prueba con el título y un saludo; el botón o la tecla **L** (en mando, el botón Back/Select) cambia entre español e inglés, y el idioma elegido se recuerda para la próxima vez.
