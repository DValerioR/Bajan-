extends Node
## Lee los números de diseño desde config/juego.cfg.
## El resto del juego consulta estos valores en lugar de usar números fijos.

const RUTA_CONFIG := "res://config/juego.cfg"

var max_jugadores: int = 4
var idioma_predeterminado: String = "es"
var idiomas_disponibles: PackedStringArray = PackedStringArray(["es", "en"])


func _init() -> void:
	cargar()


func cargar() -> void:
	var archivo := ConfigFile.new()
	var error := archivo.load(RUTA_CONFIG)
	if error != OK:
		push_error("No se pudo leer %s (error %d); se usan valores por defecto." % [RUTA_CONFIG, error])
		return
	max_jugadores = archivo.get_value("jugadores", "max_jugadores", max_jugadores)
	idioma_predeterminado = archivo.get_value("idioma", "predeterminado", idioma_predeterminado)
	idiomas_disponibles = PackedStringArray(archivo.get_value("idioma", "disponibles", idiomas_disponibles))
