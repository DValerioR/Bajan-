class_name HudInterior
extends CanvasLayer
## Interfaz del interior (etapas 2 a 4): dinero, ventana de parada, velocidad, modo del chofer
## automático, estado del jugador, avisos de sustos y ayuda de controles.
## No lee el estado del juego: la escena le pasa los datos. Los textos son claves de traducción.

const AYUDA := ["AYUDA_TITULO", "AYUDA_CAMINAR", "AYUDA_MIRAR", "AYUDA_SUJETARSE", "AYUDA_AGARRAR", "AYUDA_COBRAR", "AYUDA_PILOTO", "AYUDA_REINICIAR_INTERIOR", "AYUDA_CONFIG", "AYUDA_SALIR"]
const DURACION_AVISO := 1.2

var _velocidad: Label
var _pasajeros: Label
var _piloto: Label
var _estado: Label
var _aviso: Label
var _tiempo_aviso: float = 0.0
var _dinero: Label
var _parada: Label
var _ventana: Label
var _mensaje: Label
var _tiempo_mensaje: float = 0.0


func _ready() -> void:
	var ayuda := VBoxContainer.new()
	ayuda.position = Vector2(16, 14)
	add_child(ayuda)
	for clave in AYUDA:
		ayuda.add_child(_etiqueta(clave, 15 if clave != "AYUDA_TITULO" else 18, Color(1, 0.86, 0.3) if clave == "AYUDA_TITULO" else Color.WHITE))

	var abajo := VBoxContainer.new()
	abajo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	abajo.offset_left = -520
	abajo.offset_top = -140
	abajo.offset_right = -20
	abajo.offset_bottom = -16
	abajo.alignment = BoxContainer.ALIGNMENT_END
	add_child(abajo)
	_pasajeros = _etiqueta("", 20, Color(0.85, 1.0, 0.85))
	_pasajeros.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_pasajeros.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	abajo.add_child(_pasajeros)
	_piloto = _etiqueta("", 20, Color.WHITE)
	_piloto.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_piloto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	abajo.add_child(_piloto)
	_velocidad = _etiqueta("", 44, Color(1, 0.95, 0.85))
	_velocidad.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_velocidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	abajo.add_child(_velocidad)

	_estado = _etiqueta("", 26, Color(1, 0.8, 0.35))
	_estado.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_estado.offset_left = -400
	_estado.offset_right = 400
	_estado.offset_top = -150
	_estado.offset_bottom = -110
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_estado)

	_aviso = _etiqueta("", 40, Color(1, 0.4, 0.3))
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.offset_left = -400
	_aviso.offset_right = 400
	_aviso.offset_top = 70
	_aviso.offset_bottom = 130
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.visible = false
	add_child(_aviso)

	_dinero = _etiqueta("", 22, Color(0.75, 1.0, 0.6))
	_dinero.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_dinero.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_dinero.offset_left = -560
	_dinero.offset_right = -20
	_dinero.offset_top = 14
	_dinero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_dinero)
	_parada = _etiqueta("", 20, Color(0.8, 0.9, 1.0))
	_parada.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_parada.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_parada.offset_left = -560
	_parada.offset_right = -20
	_parada.offset_top = 104
	_parada.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_parada)
	_ventana = _etiqueta("", 34, Color(1.0, 0.95, 0.5))
	_ventana.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ventana.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_ventana.offset_left = -300
	_ventana.offset_right = 300
	_ventana.offset_top = 14
	_ventana.offset_bottom = 60
	_ventana.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_ventana)
	_mensaje = _etiqueta("", 28, Color(1.0, 1.0, 1.0))
	_mensaje.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mensaje.offset_left = -400
	_mensaje.offset_right = 400
	_mensaje.offset_top = 40
	_mensaje.offset_bottom = 90
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.visible = false
	add_child(_mensaje)

	# Mira en el centro de la pantalla, para apuntar al agarrar y empujar.
	var mira := _etiqueta("·", 30, Color.WHITE)
	mira.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mira.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mira.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(mira)


func mostrar_estado(velocidad_kmh: float, modo_piloto: String, dentro: bool, sujetado: bool, tropezando: bool) -> void:
	_velocidad.text = tr("HUD_VELOCIDAD") % absi(roundi(velocidad_kmh))
	_piloto.text = tr("HUD_PILOTO") % tr("PILOTO_" + modo_piloto.to_upper())
	if not dentro:
		_estado.text = "HUD_FUERA"
	elif tropezando:
		_estado.text = "HUD_TROPEZANDO"
	elif sujetado:
		_estado.text = "HUD_SUJETADO"
	else:
		_estado.text = ""


## Dinero de la ruta: fondo común, ganancia contra cuota y lo que trae el cobrador.
func mostrar_dinero(fondo: int, ganancia: int, cuota: int, morral: int) -> void:
	_dinero.text = "%s\n%s\n%s" % [tr("HUD_FONDO") % fondo, tr("HUD_GANANCIA") % [ganancia, cuota], tr("HUD_MORRAL") % morral]
	_dinero.add_theme_color_override("font_color", Color(0.75, 1.0, 0.6) if ganancia >= cuota else Color(1.0, 0.9, 0.6))


## En qué parada va la ruta (k de total) y, si el camión está en una, cuánto le queda a la ventana.
func mostrar_parada(siguiente: int, total: int, segundos_restantes: float, en_parada: bool) -> void:
	_parada.text = tr("HUD_PARADA") % [mini(siguiente, total), total] if total > 0 else ""
	_ventana.visible = en_parada
	if en_parada:
		_ventana.text = tr("HUD_VENTANA") % ceili(maxf(segundos_restantes, 0.0)) if segundos_restantes > 0.0 else tr("HUD_VENTANA_PASADA")
		_ventana.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5) if segundos_restantes > 0.0 else Color(1.0, 0.4, 0.3))


## Mensaje corto (ya traducido y armado), por ejemplo "+12" o "Se te regaron $8".
func mensaje(texto: String, color: Color = Color.WHITE) -> void:
	_mensaje.text = texto
	_mensaje.add_theme_color_override("font_color", color)
	_mensaje.visible = true
	_tiempo_mensaje = 1.6


func mostrar_pasajeros(cuantos: int) -> void:
	_pasajeros.text = tr("HUD_PASAJEROS") % cuantos


func avisar_susto(tipo: String) -> void:
	_aviso.text = "HUD_SUSTO_" + tipo.to_upper()
	_aviso.visible = true
	_tiempo_aviso = DURACION_AVISO


func _process(delta: float) -> void:
	if _tiempo_mensaje > 0.0:
		_tiempo_mensaje -= delta
		if _tiempo_mensaje <= 0.0:
			_mensaje.visible = false
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		if _tiempo_aviso <= 0.0:
			_aviso.visible = false


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.06))
	etiqueta.add_theme_constant_override("outline_size", 6 if tamano < 30 else 10)
	return etiqueta
