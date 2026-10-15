extends Control
## Escena de prueba de la etapa 0: muestra textos traducidos y permite cambiar de idioma.
## Los textos de los nodos son claves de traducción (traducciones/textos.csv);
## Godot los traduce solo gracias a auto_translate.


func _ready() -> void:
	%BotonIdioma.pressed.connect(Preferencias.siguiente_idioma)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("cambiar_idioma"):
		Preferencias.siguiente_idioma()
		get_viewport().set_input_as_handled()
