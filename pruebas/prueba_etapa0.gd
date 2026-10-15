extends Node
## Prueba automática de la etapa 0. Se corre en modo headless con pruebas.bat.
## Sale con código 0 si todo pasa y 1 si algo falla.

const RUTA_TEXTOS := "res://traducciones/textos.csv"

var _fallos: int = 0


func _ready() -> void:
	var idioma_original: String = Preferencias.idioma

	_probar_config()
	_probar_traducciones()
	await _probar_escena_principal()
	_probar_cambio_de_idioma()

	Preferencias.cambiar_idioma(idioma_original)
	if _fallos == 0:
		print("PRUEBAS ETAPA 0: todo pasó.")
	else:
		printerr("PRUEBAS ETAPA 0: %d fallo(s)." % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("  ok    ", descripcion)
	else:
		printerr("  FALLO ", descripcion)
		_fallos += 1


func _probar_config() -> void:
	print("Config:")
	_verificar(Config.max_jugadores == 4, "MAX_JUGADORES se lee de config/juego.cfg (= 4)")
	_verificar(Config.idioma_predeterminado == "es", "el idioma predeterminado es español")
	_verificar(Config.idiomas_disponibles == PackedStringArray(["es", "en"]), "idiomas disponibles: es, en")
	var motor: String = ProjectSettings.get_setting("physics/3d/physics_engine")
	_verificar(motor == "Jolt Physics", "el motor de física 3D es Jolt (%s)" % motor)


func _probar_traducciones() -> void:
	print("Traducciones:")
	var claves := _leer_claves()
	_verificar(claves.size() > 0, "textos.csv tiene claves")
	for locale in Config.idiomas_disponibles:
		TranslationServer.set_locale(locale)
		for clave in claves:
			var texto := tr(clave)
			_verificar(texto != clave and not texto.is_empty(), "[%s] %s -> %s" % [locale, clave, texto])
	TranslationServer.set_locale("es")
	var es := tr("PRUEBA_SALUDO")
	TranslationServer.set_locale("en")
	var en := tr("PRUEBA_SALUDO")
	_verificar(es != en, "el saludo cambia entre español e inglés")


func _probar_escena_principal() -> void:
	print("Escena principal:")
	var ruta: String = ProjectSettings.get_setting("application/run/main_scene")
	var escena := load(ruta) as PackedScene
	_verificar(escena != null, "la escena principal carga (%s)" % ruta)
	if escena == null:
		return
	var principal := escena.instantiate()
	add_child(principal)
	await get_tree().process_frame
	_verificar(principal.is_inside_tree(), "la escena principal se instancia sin errores")
	principal.queue_free()


func _probar_cambio_de_idioma() -> void:
	print("Cambio de idioma:")
	Preferencias.cambiar_idioma("es")
	_verificar(TranslationServer.get_locale().begins_with("es"), "cambiar_idioma('es') pone español")
	Preferencias.siguiente_idioma()
	_verificar(TranslationServer.get_locale().begins_with("en"), "siguiente_idioma() pasa a inglés")
	Preferencias.siguiente_idioma()
	_verificar(TranslationServer.get_locale().begins_with("es"), "siguiente_idioma() regresa a español")


func _leer_claves() -> PackedStringArray:
	var claves := PackedStringArray()
	var archivo := FileAccess.open(RUTA_TEXTOS, FileAccess.READ)
	if archivo == null:
		return claves
	archivo.get_csv_line()  # Encabezado: keys,es,en
	while not archivo.eof_reached():
		var fila := archivo.get_csv_line()
		if fila.size() > 0 and not fila[0].is_empty():
			claves.append(fila[0])
	return claves
