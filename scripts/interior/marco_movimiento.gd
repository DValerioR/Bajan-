class_name MarcoMovimiento
extends RefCounted
## Le dice a un cuerpo (personaje u objeto) qué gravedad y qué empujones siente en el espacio
## donde vive. Este marco base es la calle: gravedad normal y nada más.
## Todos los vectores están en las coordenadas del espacio de física del cuerpo.

const GRAVEDAD := Vector3(0.0, -9.8, 0.0)


## Hacia dónde es "arriba" para el cuerpo.
func arriba(_posicion: Vector3) -> Vector3:
	return Vector3.UP


## Gravedad aparente (m/s²).
func gravedad(_posicion: Vector3) -> Vector3:
	return GRAVEDAD


## Empujón horizontal por la inercia del camión (m/s²), ya exagerado y con tope.
func empuje(_posicion: Vector3) -> Vector3:
	return Vector3.ZERO


## Si el empujón se sigue sintiendo cuando el cuerpo va en el aire.
func empuje_en_aire() -> bool:
	return false


## Cuánto gira (rad) el "piso" alrededor de `arriba` en este cuadro, para girar con él.
func giro(_delta: float) -> float:
	return 0.0


## Si hay algo de dónde sujetarse cerca de la mano (pasamanos, poste, respaldo).
func pasamanos_cerca(_posicion: Vector3, _alcance_altura: float, _alcance: float) -> bool:
	return false


## Si el cuerpo está dentro de un camión (para la interfaz y las transiciones).
func en_camion() -> bool:
	return false
