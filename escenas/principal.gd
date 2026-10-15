extends Control
## Menú de pruebas: abre la escena de cada etapa y permite cambiar de idioma.
## Los textos de los nodos son claves de traducción (traducciones/textos.csv);
## Godot los traduce solo gracias a auto_translate.

const ESCENA_CALLE := "res://escenas/calle_prueba/calle_prueba.tscn"


func _ready() -> void:
	%BotonIdioma.pressed.connect(Preferencias.siguiente_idioma)
	%BotonCalle.pressed.connect(_abrir_calle)
	%BotonCalle.grab_focus()


func _abrir_calle() -> void:
	get_tree().change_scene_to_file(ESCENA_CALLE)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("cambiar_idioma"):
		Preferencias.siguiente_idioma()
		get_viewport().set_input_as_handled()
