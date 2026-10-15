class_name MarcoInteriorMundo
extends MarcoMovimiento
## Prototipo A: el cuerpo vive en el mundo normal, parado sobre el piso del camión, que es una
## plataforma que se mueve. Godot lo lleva con la plataforma; aquí solo se agregan los
## empujones por inercia (mientras pisa el camión) y el giro, para que voltee junto con el camión.

var inercia: InerciaCamion
var parametros: ParametrosInterior
var exageracion: float = 1.0


func _init(inercia_camion: InerciaCamion, p: ParametrosInterior, factor: float) -> void:
	inercia = inercia_camion
	parametros = p
	exageracion = factor


func arriba(_posicion: Vector3) -> Vector3:
	return inercia.camion.global_basis.y


func empuje(posicion: Vector3) -> Vector3:
	var arriba_camion := inercia.camion.global_basis.y
	var ficticia := inercia.ficticia(posicion) * exageracion
	var horizontal := ficticia - arriba_camion * ficticia.dot(arriba_camion)
	return horizontal.limit_length(parametros.empujon_maximo)


func giro(delta: float) -> float:
	return inercia.velocidad_angular.dot(inercia.camion.global_basis.y) * delta


func pasamanos_cerca(posicion: Vector3, alcance_altura: float, alcance: float) -> bool:
	var local := inercia.camion.global_transform.affine_inverse() * posicion
	return GeometriaInterior.agarradera_cerca(local, alcance_altura, alcance)


func en_camion() -> bool:
	return true
