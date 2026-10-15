class_name InerciaCamion
extends Node
## Mide cómo se mueve el camión (aceleración y giro, suavizados) y calcula la aceleración
## ficticia que siente cualquier punto de su interior: lo que "empuja" a la gente cuando el
## camión frena, acelera, da vuelta o brinca. Es la base del interior (MarcoInterior).

@export var camion: Camion

## Aceleración del centro de masa del camión (m/s², mundo), sin gravedad y suavizada.
var aceleracion := Vector3.ZERO
## Velocidad y aceleración angular del camión (rad/s y rad/s², mundo).
var velocidad_angular := Vector3.ZERO
var aceleracion_angular := Vector3.ZERO

var _velocidad_anterior := Vector3.ZERO
var _angular_anterior := Vector3.ZERO
var _primera := true
var _suavizado := 0.06


func _ready() -> void:
	# Corre después del camión en cada cuadro de física.
	process_physics_priority = 10
	_aplicar_parametros()
	Config.recargado.connect(_aplicar_parametros)


func _aplicar_parametros() -> void:
	_suavizado = ParametrosInterior.cargar().suavizado


## Olvida la historia (después de teletransportar el camión), para no inventar un golpe.
func reiniciar() -> void:
	_primera = true


func _physics_process(delta: float) -> void:
	var v := camion.linear_velocity
	var w := camion.angular_velocity
	if _primera:
		_velocidad_anterior = v
		_angular_anterior = w
		aceleracion = Vector3.ZERO
		aceleracion_angular = Vector3.ZERO
		_primera = false
	var t := 1.0 - exp(-delta / maxf(_suavizado, 0.001))
	aceleracion = aceleracion.lerp((v - _velocidad_anterior) / delta, t)
	aceleracion_angular = aceleracion_angular.lerp((w - _angular_anterior) / delta, t)
	velocidad_angular = w
	_velocidad_anterior = v
	_angular_anterior = w


## Aceleración ficticia (m/s², mundo) en un punto del mundo que viaja con el camión:
## -(aceleración del centro) - (aceleración angular × r) - (centrífuga).
func ficticia(punto: Vector3) -> Vector3:
	var r := punto - camion.global_transform * camion.center_of_mass
	return -(aceleracion + aceleracion_angular.cross(r) + velocidad_angular.cross(velocidad_angular.cross(r)))


## Velocidad (m/s, mundo) de un punto que viaja pegado al camión.
func velocidad_en(punto: Vector3) -> Vector3:
	var r := punto - camion.global_transform * camion.center_of_mass
	return camion.linear_velocity + camion.angular_velocity.cross(r)
