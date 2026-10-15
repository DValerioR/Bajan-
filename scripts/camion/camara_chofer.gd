class_name CamaraChofer
extends Camera3D
## Cámara en primera persona del chofer. Gira la cabeza con el ratón o el stick derecho,
## dentro de los límites de config/conduccion.cfg. Va dentro de la carrocería,
## así que se balancea con ella.

@export var camion: Camion

var _horizontal: float = 0.0
var _vertical: float = 0.0


func _unhandled_input(evento: InputEvent) -> void:
	# El movimiento del ratón no es una tecla: se lee directo, como en cualquier cámara de primera persona.
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var p := camion.parametros
		_horizontal -= evento.relative.x * p.sensibilidad_raton
		_vertical -= evento.relative.y * p.sensibilidad_raton


func _process(delta: float) -> void:
	var p := camion.parametros
	_horizontal -= Input.get_axis("mirar_izquierda", "mirar_derecha") * p.sensibilidad_mando * delta
	_vertical -= Input.get_axis("mirar_arriba", "mirar_abajo") * p.sensibilidad_mando * delta
	_horizontal = clampf(_horizontal, -p.limite_horizontal, p.limite_horizontal)
	_vertical = clampf(_vertical, -p.limite_vertical, p.limite_vertical)
	rotation_degrees = Vector3(_vertical, _horizontal, 0.0)
