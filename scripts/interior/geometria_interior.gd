class_name GeometriaInterior
extends RefCounted
## Colisiones y agarraderas del interior del camión, sacadas de las mismas piezas que dibuja
## la carrocería (scripts/camion/carroceria_basica.gd), en coordenadas del camión.
## Si cambia la carrocería, el interior cambia con ella.

const Carroceria := preload("res://scripts/camion/carroceria_basica.gd")
## La carrocería está 0.3 m abajo del origen del camión (ver escenas/camion/camion.tscn).
const DESPLAZAMIENTO := Vector3(0.0, -0.3, 0.0)
## Piezas que son solo adorno o están por fuera: no estorban a la gente.
const SIN_COLISION := ["FranjaIzquierda", "FranjaDerecha", "ParachoquesDelantero", "ParachoquesTrasero"]

## Volumen del interior, en coordenadas del camión (para saber si algo está adentro).
const LIMITES := AABB(Vector3(-1.25, -0.4, -4.02), Vector3(2.5, 2.75, 8.04))


## Formas sólidas del interior: [Shape3D, Transform3D], en coordenadas del camión.
static func formas() -> Array:
	var lista := []
	for pieza in Carroceria.PIEZAS:
		if pieza[1] != "caja" or pieza[0] in SIN_COLISION:
			continue
		lista.append(_caja(pieza[2], pieza[3], pieza[4]))
	for z in Carroceria.PILARES_IZQUIERDA:
		lista.append(_caja(Vector3(0.08, 1.0, 0.12), Vector3(-1.21, 1.5, z), Vector3.ZERO))
	for z in Carroceria.PILARES_DERECHA:
		lista.append(_caja(Vector3(0.08, 1.0, 0.12), Vector3(1.21, 1.5, z), Vector3.ZERO))
	for z in Carroceria.FILAS_ASIENTOS:
		for x in [-0.72, 0.72]:
			lista.append(_caja(Vector3(0.85, 0.45, 0.5), Vector3(x, 0.225, z), Vector3.ZERO))
			lista.append(_caja(Vector3(0.85, 0.6, 0.1), Vector3(x, 0.75, z + 0.25), Vector3.ZERO))
	return lista


## Agarraderas: segmentos [desde, hasta] en coordenadas del camión.
static func agarraderas() -> Array:
	var lista := []
	for x in [-0.45, 0.45]:
		lista.append([Vector3(x, 2.05, 0.2 - 3.7) + DESPLAZAMIENTO, Vector3(x, 2.05, 0.2 + 3.7) + DESPLAZAMIENTO])
	lista.append([Vector3(0.95, 0.2, -2.5) + DESPLAZAMIENTO, Vector3(0.95, 2.3, -2.5) + DESPLAZAMIENTO])
	# El borde de arriba de cada respaldo, del lado del pasillo: para quien no alcanza el pasamanos.
	for z in Carroceria.FILAS_ASIENTOS:
		for lado in [-1.0, 1.0]:
			lista.append([Vector3(0.3 * lado, 1.05, z + 0.25) + DESPLAZAMIENTO, Vector3(0.75 * lado, 1.05, z + 0.25) + DESPLAZAMIENTO])
	return lista


## Si hay una agarradera al alcance: a menos de `alcance` del hombro y no más alta que `alcance_altura`
## sobre los pies. `pies` va en coordenadas del camión.
static func agarradera_cerca(pies: Vector3, alcance_altura: float, alcance: float) -> bool:
	var hombro := pies + Vector3.UP * alcance_altura * 0.65
	for segmento in agarraderas():
		var a: Vector3 = segmento[0]
		var b: Vector3 = segmento[1]
		var ab := b - a
		var t := clampf((hombro - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var punto := a + ab * t
		if punto.y - pies.y <= alcance_altura and punto.distance_to(hombro) <= alcance:
			return true
	return false


static func _caja(medidas: Vector3, posicion: Vector3, rotacion: Vector3) -> Array:
	var forma := BoxShape3D.new()
	forma.size = medidas
	var base := Basis.from_euler(rotacion * PI / 180.0)
	return [forma, Transform3D(base, posicion + DESPLAZAMIENTO)]
