extends Node
## Preferencias locales del jugador (idioma, y más adelante controles, volumen, etc.).
## Se guardan en user://preferencias.cfg y no forman parte del estado de la partida.

signal idioma_cambiado(locale: String)

const RUTA_PREFERENCIAS := "user://preferencias.cfg"

var idioma: String = ""


func _ready() -> void:
	var archivo := ConfigFile.new()
	if archivo.load(RUTA_PREFERENCIAS) == OK:
		idioma = archivo.get_value("idioma", "locale", "")
	if not idioma in Config.idiomas_disponibles:
		idioma = Config.idioma_predeterminado
	TranslationServer.set_locale(idioma)


func cambiar_idioma(locale: String) -> void:
	if not locale in Config.idiomas_disponibles:
		push_warning("Idioma no disponible: %s" % locale)
		return
	idioma = locale
	TranslationServer.set_locale(idioma)
	_guardar()
	idioma_cambiado.emit(idioma)


## Pasa al siguiente idioma de la lista de Config.idiomas_disponibles.
func siguiente_idioma() -> void:
	var disponibles := Config.idiomas_disponibles
	var indice := disponibles.find(idioma)
	cambiar_idioma(disponibles[(indice + 1) % disponibles.size()])


func _guardar() -> void:
	var archivo := ConfigFile.new()
	archivo.load(RUTA_PREFERENCIAS)
	archivo.set_value("idioma", "locale", idioma)
	var error := archivo.save(RUTA_PREFERENCIAS)
	if error != OK:
		push_error("No se pudieron guardar las preferencias (error %d)." % error)
