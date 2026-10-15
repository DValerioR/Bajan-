# Bajan! — Créditos y licencias

Registro de cada recurso externo o generado con IA que se use en el juego: qué es, de dónde viene, su licencia y si es generado con IA. Steam exige declarar el contenido generado con IA al publicar (DISEÑO.md, sección 11), así que **todo** recurso que entre al proyecto se anota aquí en el mismo commit en que se agrega.

## Motor y bibliotecas

| Recurso | Uso | Fuente | Licencia | ¿IA? |
|---|---|---|---|---|
| Godot Engine 4.7.2 | Motor del juego | https://godotengine.org | MIT | No |
| Jolt Physics (integrado en Godot) | Física 3D | https://github.com/jrouwe/JoltPhysics | MIT | No |
| Bibliotecas de terceros incluidas en Godot (fuentes por defecto, FreeType, etc.) | Incluidas en el motor | `COPYRIGHT.txt` de Godot | Varias (MIT, OFL, Apache 2.0, etc.) | No |

Al exportar el juego hay que incluir los avisos de licencia de Godot y de sus bibliotecas de terceros (por ejemplo, en una pantalla de créditos o un archivo junto al ejecutable). Pendiente para la etapa 9.

## Código y textos

| Recurso | Uso | Fuente | Licencia | ¿IA? |
|---|---|---|---|---|
| Código GDScript, escenas y textos del juego | Todo el proyecto | Escrito para Bajan! con asistencia de Claude (Anthropic) | Propiedad del proyecto | Sí, asistido con IA |

## Arte, modelos y texturas

Ninguno todavía. Por ahora todo se construye con formas básicas dentro del proyecto.

## Música y efectos de sonido

| Recurso | Uso | Fuente | Licencia | ¿IA? |
|---|---|---|---|---|
| Motor y claxon del camión | Sonidos de relleno | Generados en código por `scripts/audio/sintetizador.gd` (ondas sierra y cuadradas) | Propiedad del proyecto | No |

## Plantilla para nuevas entradas

| Recurso | Uso | Fuente | Licencia | ¿IA? |
|---|---|---|---|---|
| nombre del archivo o paquete | dónde se usa | URL o herramienta (y modelo de IA, si aplica) | licencia exacta | Sí/No, y qué herramienta |
