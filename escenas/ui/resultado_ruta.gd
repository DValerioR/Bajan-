class_name ResultadoRuta
extends CanvasLayer
## Pantalla al terminar una ruta (DISEÑO.md, 6.1 y 6.4): si se cumplió la cuota, cuánto se ganó
## y cómo queda el fondo; si no, el fin de la partida con su récord.
## No toca el estado del juego: recibe los datos y avisa qué botón se presionó.

signal siguiente_ruta
signal volver_al_menu


## `datos`: {cumplida, ganancia, cuota, fondo, cobrados, sin_pagar, regado, perdido,
##           rutas_cumplidas, total_ganado}.
func mostrar(datos: Dictionary) -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.05, 0.04, 0.06, 0.78)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	centro.add_child(columna)

	var cumplida: bool = datos.cumplida
	columna.add_child(_texto("RESULTADO_CUMPLIDA" if cumplida else "RESULTADO_FALLIDA", 54, Color(0.6, 1.0, 0.5) if cumplida else Color(1.0, 0.45, 0.35), true))
	columna.add_child(_texto(tr("RESULTADO_GANANCIA") % datos.ganancia, 28))
	columna.add_child(_texto(tr("RESULTADO_CUOTA") % datos.cuota, 28))
	if cumplida:
		columna.add_child(_texto(tr("RESULTADO_FONDO") % datos.fondo, 28))
	columna.add_child(_texto(tr("RESULTADO_COBRADOS") % [datos.cobrados, datos.sin_pagar], 22, Color(0.85, 0.85, 0.85)))
	columna.add_child(_texto(tr("RESULTADO_REGADO") % [datos.regado, datos.perdido], 22, Color(0.85, 0.85, 0.85)))
	if not cumplida:
		columna.add_child(_texto(tr("RESULTADO_FIN") % [datos.rutas_cumplidas, datos.total_ganado], 26, Color(1.0, 0.85, 0.5)))

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 20)
	columna.add_child(botones)
	if cumplida:
		var siguiente := _boton("BOTON_SIGUIENTE_RUTA")
		siguiente.pressed.connect(siguiente_ruta.emit)
		botones.add_child(siguiente)
		siguiente.grab_focus.call_deferred()
	var menu := _boton("BOTON_MENU")
	menu.pressed.connect(volver_al_menu.emit)
	botones.add_child(menu)
	if not cumplida:
		menu.grab_focus.call_deferred()


func _texto(texto: String, tamano: int, color: Color = Color.WHITE, traducir: bool = false) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if traducir else Node.AUTO_TRANSLATE_MODE_DISABLED
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.04))
	etiqueta.add_theme_constant_override("outline_size", 8)
	return etiqueta


func _boton(clave: String) -> Button:
	var boton := Button.new()
	boton.text = clave
	boton.custom_minimum_size = Vector2(360, 60)
	boton.add_theme_font_size_override("font_size", 24)
	return boton
