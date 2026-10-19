extends Control
## Menú de pruebas: abre la escena de cada etapa y permite cambiar de idioma.
## Los textos de los nodos son claves de traducción (traducciones/textos.csv);
## Godot los traduce solo gracias a auto_translate.

const ESCENA_CALLE := "res://escenas/calle_prueba/calle_prueba.tscn"
const ESCENA_INTERIOR := "res://escenas/interior_prueba/interior_prueba.tscn"
const ESCENA_RUTA := "res://escenas/ruta/ruta.tscn"


## Botones para elegir el rol, en orden.
const ROLES_MENU := ["chofer", "cobrador", "voceador", "vendedor", "azar"]


func _ready() -> void:
	_armar_eleccion_de_rol()
	%BotonIdioma.pressed.connect(Preferencias.siguiente_idioma)
	%BotonCalle.pressed.connect(_abrir_calle)
	%BotonInterior.pressed.connect(_abrir_interior)
	%BotonRuta.pressed.connect(_abrir_ruta)
	%BotonRuta.grab_focus()


func _abrir_calle() -> void:
	get_tree().change_scene_to_file(ESCENA_CALLE)


## Debajo de "Jugar una ruta": con qué rol se juega (Modo normal, sección 5.3).
func _armar_eleccion_de_rol() -> void:
	var columna: VBoxContainer = %BotonRuta.get_parent()
	var titulo := Label.new()
	titulo.text = "ELEGIR_ROL"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(0.13, 0.11, 0.1))
	var fila := HBoxContainer.new()
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
	# Con la fila de roles, el menú ya no cabe con tanto espacio entre renglones.
	columna.add_theme_constant_override("separation", 10)
	var despues := %BotonRuta.get_index() + 1
	columna.add_child(titulo)
	columna.move_child(titulo, despues)
	columna.add_child(fila)
	columna.move_child(fila, despues + 1)


func _abrir_ruta() -> void:
	Juego.nueva_partida(-1, Preferencias.rol)
	get_tree().change_scene_to_file(ESCENA_RUTA)


func _abrir_interior() -> void:
	get_tree().change_scene_to_file(ESCENA_INTERIOR)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("cambiar_idioma"):
		Preferencias.siguiente_idioma()
		get_viewport().set_input_as_handled()
