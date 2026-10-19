extends Control
## Menú de pruebas: abre la escena de cada etapa y permite cambiar de idioma.
## Los textos de los nodos son claves de traducción (traducciones/textos.csv);
## Godot los traduce solo gracias a auto_translate.

const ESCENA_CALLE := "res://escenas/calle_prueba/calle_prueba.tscn"
const ESCENA_INTERIOR := "res://escenas/interior_prueba/interior_prueba.tscn"
const ESCENA_RUTA := "res://escenas/ruta/ruta.tscn"


## Botones para elegir el rol, en orden.
const ROLES_MENU := ["chofer", "cobrador", "voceador", "vendedor", "azar"]

var _fila_roles: HBoxContainer


func _ready() -> void:
	_armar_eleccion_de_rol()
	%BotonIdioma.pressed.connect(Preferencias.siguiente_idioma)
	%BotonCalle.pressed.connect(_abrir_calle)
	%BotonInterior.pressed.connect(_abrir_interior)
	%BotonRuta.pressed.connect(_abrir_ruta)
	%BotonRuta.grab_focus()


func _abrir_calle() -> void:
	get_tree().change_scene_to_file(ESCENA_CALLE)


## Debajo de "Jugar una ruta": el modo y, en Modo normal, con qué rol se juega (sección 5.3).
func _armar_eleccion_de_rol() -> void:
	var columna: VBoxContainer = %BotonRuta.get_parent()
	var fila_modos := HBoxContainer.new()
	fila_modos.name = "Modos"
	fila_modos.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_modos.add_theme_constant_override("separation", 8)
	var grupo_modos := ButtonGroup.new()
	for modo in ["normal", "paro"]:
		var boton := Button.new()
		boton.name = "Modo_" + modo
		boton.text = "MODO_" + modo.to_upper()
		boton.toggle_mode = true
		boton.button_group = grupo_modos
		boton.custom_minimum_size = Vector2(250, 48)
		boton.add_theme_font_size_override("font_size", 20)
		boton.button_pressed = modo == Preferencias.modo
		boton.pressed.connect(_elegir_modo.bind(modo))
		fila_modos.add_child(boton)
	var titulo := Label.new()
	titulo.text = "ELEGIR_ROL"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(0.13, 0.11, 0.1))
	var fila := HBoxContainer.new()
	_fila_roles = fila
	fila.name = "Roles"
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	var grupo := ButtonGroup.new()
	for rol in ROLES_MENU:
		var boton := Button.new()
		boton.name = "Rol_" + rol
		boton.text = "ROL_" + rol.to_upper()
		boton.toggle_mode = true
		boton.button_group = grupo
		boton.custom_minimum_size = Vector2(130, 48)
		boton.add_theme_font_size_override("font_size", 20)
		boton.button_pressed = rol == Preferencias.rol
		boton.pressed.connect(Preferencias.elegir_rol.bind(rol))
		fila.add_child(boton)
	# Con las filas de modo y de rol, el menú ya no cabe con tanto espacio ni un título tan grande.
	columna.add_theme_constant_override("separation", 8)
	%Titulo.add_theme_font_size_override("font_size", 76)
	var despues := %BotonRuta.get_index() + 1
	columna.add_child(fila_modos)
	columna.move_child(fila_modos, despues)
	columna.add_child(titulo)
	columna.move_child(titulo, despues + 1)
	columna.add_child(fila)
	columna.move_child(fila, despues + 2)
	_elegir_modo(Preferencias.modo)


## En "Tírame paro" el rol se reparte al azar: no se elige.
func _elegir_modo(modo: String) -> void:
	Preferencias.elegir_modo(modo)
	for boton: Button in _fila_roles.get_children():
		boton.disabled = modo == "paro"


func _abrir_ruta() -> void:
	if Preferencias.modo == "paro":
		var rol := Juego.rol_para_empezar_paro(Preferencias.rol_inicio_paro)
		Preferencias.empezo_paro_con(rol)
		Juego.nueva_partida(-1, rol, "paro")
	else:
		Juego.nueva_partida(-1, Preferencias.rol, "normal")
	get_tree().change_scene_to_file(ESCENA_RUTA)


func _abrir_interior() -> void:
	get_tree().change_scene_to_file(ESCENA_INTERIOR)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("cambiar_idioma"):
		Preferencias.siguiente_idioma()
		get_viewport().set_input_as_handled()
