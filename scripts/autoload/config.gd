extends Node
## Lee los números de diseño desde los archivos de config/.
## El resto del juego consulta estos valores en lugar de usar números fijos.
## Con la acción "recargar_config" (F9) se releen todos los archivos sin cerrar el juego.

signal recargado

const RUTA_CONFIG := "res://config/juego.cfg"

var max_jugadores: int = 4
var idioma_predeterminado: String = "es"
var idiomas_disponibles: PackedStringArray = PackedStringArray(["es", "en"])

var _archivos: Dictionary = {}


func _init() -> void:
	cargar()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("recargar_config"):
		recargar()


func cargar() -> void:
	var archivo := archivo_config(RUTA_CONFIG)
	max_jugadores = archivo.get_value("jugadores", "max_jugadores", max_jugadores)
	idioma_predeterminado = archivo.get_value("idioma", "predeterminado", idioma_predeterminado)
	idiomas_disponibles = PackedStringArray(archivo.get_value("idioma", "disponibles", idiomas_disponibles))


## Devuelve el ConfigFile de la ruta indicada, leyéndolo la primera vez.
func archivo_config(ruta: String) -> ConfigFile:
	if not _archivos.has(ruta):
		var archivo := ConfigFile.new()
		var error := archivo.load(ruta)
		if error != OK:
			push_error("No se pudo leer %s (error %d); se usan valores por defecto." % [ruta, error])
		_archivos[ruta] = archivo
	return _archivos[ruta]


## Vuelve a leer todos los archivos de configuración y avisa con la señal recargado.
func recargar() -> void:
	_archivos.clear()
	cargar()
	print("Configuración recargada.")
	recargado.emit()
