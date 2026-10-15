class_name HudConduccion
extends CanvasLayer
## Interfaz de manejo: velocímetro, ayuda de controles y avisos cortos.
## No lee el estado del juego: la escena le pasa los datos.

## Segundos con las cuatro llantas en el aire antes de sugerir enderezar el camión.
const SEGUNDOS_PARA_SUGERIR_REINICIO := 2.5
const DURACION_AVISO := 2.0

var _tiempo_sin_llantas: float = 0.0
var _tiempo_aviso: float = 0.0


func mostrar_telemetria(velocidad_kmh: float, ruedas_en_suelo: int) -> void:
	%Velocidad.text = tr("HUD_VELOCIDAD") % absi(roundi(velocidad_kmh))
	if ruedas_en_suelo == 0:
		_tiempo_sin_llantas += get_physics_process_delta_time()
	else:
		_tiempo_sin_llantas = 0.0
	%Reiniciar.visible = _tiempo_sin_llantas > SEGUNDOS_PARA_SUGERIR_REINICIO


func avisar(clave: String) -> void:
	%Aviso.text = clave
	%Aviso.visible = true
	_tiempo_aviso = DURACION_AVISO


func _process(delta: float) -> void:
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		if _tiempo_aviso <= 0.0:
			%Aviso.visible = false
