extends Node
## Preferencias locales del jugador (idioma, y más adelante controles, volumen, etc.).
## Se guardan en user://preferencias.cfg y no forman parte del estado de la partida.

signal idioma_cambiado(locale: String)

const RUTA_PREFERENCIAS := "user://preferencias.cfg"

var idioma: String = ""
## Último rol que eligió en el menú ("azar" = al azar).
var rol: String = "cobrador"
## Último modo que eligió ("normal" o "paro") y el rol con el que empezó su última partida en
## "Tírame paro" (5.3: la siguiente empieza con otro).
var modo: String = "normal"
var rol_inicio_paro: String = ""


func _ready() -> void:
	var archivo := ConfigFile.new()
	if archivo.load(RUTA_PREFERENCIAS) == OK:
		idioma = archivo.get_value("idioma", "locale", "")
		rol = archivo.get_value("partida", "rol", rol)
		modo = archivo.get_value("partida", "modo", modo)
		rol_inicio_paro = archivo.get_value("partida", "rol_inicio_paro", rol_inicio_paro)
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


func elegir_rol(nuevo: String) -> void:
	rol = nuevo
	_guardar()


func elegir_modo(nuevo: String) -> void:
	modo = nuevo
	_guardar()


func empezo_paro_con(rol_inicial: String) -> void:
	rol_inicio_paro = rol_inicial
	_guardar()


func _guardar() -> void:
	var archivo := ConfigFile.new()
	archivo.load(RUTA_PREFERENCIAS)
	archivo.set_value("idioma", "locale", idioma)
	archivo.set_value("partida", "rol", rol)
	archivo.set_value("partida", "modo", modo)
	archivo.set_value("partida", "rol_inicio_paro", rol_inicio_paro)
	var error := archivo.save(RUTA_PREFERENCIAS)
	if error != OK:
		push_error("No se pudieron guardar las preferencias (error %d)." % error)
