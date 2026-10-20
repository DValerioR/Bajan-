class_name MarcoInterior
extends MarcoMovimiento
## Dentro del camión: el cuerpo vive en un espacio de física aparte donde el interior del camión
## está quieto, en coordenadas del camión. Todo lo que hace el camión llega como gravedad
## inclinada y empujones calculados, con tope.

var inercia: InerciaCamion
var parametros: ParametrosInterior
var exageracion: float = 1.0


func _init(inercia_camion: InerciaCamion, p: ParametrosInterior, factor: float) -> void:
	inercia = inercia_camion
	parametros = p
	exageracion = factor


func gravedad(posicion: Vector3) -> Vector3:
	var transformacion := inercia.camion.global_transform
	var g := transformacion.basis.inverse() * GRAVEDAD
	var ficticia := transformacion.basis.inverse() * inercia.ficticia(transformacion * posicion)
	# Solo la parte vertical del empujón entra a la gravedad (brincos en topes y baches), con tope.
	var vertical := clampf(ficticia.y * exageracion, -parametros.vertical_maximo, parametros.vertical_maximo)
	return g + Vector3(0.0, vertical, 0.0)


func empuje(posicion: Vector3) -> Vector3:
	var transformacion := inercia.camion.global_transform
	var ficticia := transformacion.basis.inverse() * inercia.ficticia(transformacion * posicion)
	var horizontal := Vector3(ficticia.x, 0.0, ficticia.z) * exageracion
	return horizontal.limit_length(parametros.empujon_maximo)


func sacudida(posicion: Vector3) -> Vector3:
	var transformacion := inercia.camion.global_transform
	var ficticia := transformacion.basis.inverse() * inercia.ficticia(transformacion * posicion)
	return Vector3(ficticia.x, 0.0, ficticia.z)


func empuje_en_aire() -> bool:
	return true


func pasamanos_cerca(posicion: Vector3, alcance_altura: float, alcance: float) -> bool:
	return GeometriaInterior.agarradera_cerca(posicion, alcance_altura, alcance)


func punto_de_agarre(posicion: Vector3, alcance_altura: float, alcance: float) -> Vector3:
	return GeometriaInterior.punto_de_agarre(posicion, alcance_altura, alcance)


func en_camion() -> bool:
	return true
