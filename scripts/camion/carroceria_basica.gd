@tool
extends Node3D
## Carrocería del microbús hecha con formas básicas (DISEÑO.md, sección 3).
## Se genera al cargar la escena, también en el editor, a partir de la lista de piezas.
## Cuando llegue un modelo importado, se reemplaza este nodo por el modelo y la lógica no cambia.
## Coordenadas: el piso del camión está en y = 0, el frente apunta a -Z y la derecha a +X.

const VERDE := Color(0.16, 0.58, 0.36)
const CREMA := Color(0.96, 0.9, 0.76)
const BLANCO := Color(0.97, 0.97, 0.95)
const GRIS := Color(0.55, 0.56, 0.6)
const GRIS_OSCURO := Color(0.22, 0.22, 0.26)
const NEGRO := Color(0.1, 0.1, 0.12)
const VINO := Color(0.6, 0.13, 0.2)
const AMARILLO := Color(1.0, 0.8, 0.18)
const ROJO := Color(0.88, 0.16, 0.1)
const PISO := Color(0.36, 0.31, 0.29)

## Color de la carrocería (lo que va en verde): los rivales usan otro.
@export var color_principal: Color = VERDE

## Cada pieza: [nombre, forma, medidas, posición, rotación en grados, color].
## Medidas: caja = tamaño; cilindro = (radio, alto, -); esfera = (radio, -, -); toro = (radio interior, exterior, -).
const PIEZAS := [
	["Piso", "caja", Vector3(2.92, 0.1, 7.9), Vector3(0, -0.05, 0), Vector3.ZERO, PISO],
	["FaldaIzquierda", "caja", Vector3(0.08, 1.35, 8.0), Vector3(-1.46, 0.325, 0), Vector3.ZERO, VERDE],
	["FaldaDerechaFrente", "caja", Vector3(0.08, 1.35, 0.3), Vector3(1.46, 0.325, -3.85), Vector3.ZERO, VERDE],
	["FaldaDerechaAtras", "caja", Vector3(0.08, 1.35, 6.6), Vector3(1.46, 0.325, 0.7), Vector3.ZERO, VERDE],
	["FranjaIzquierda", "caja", Vector3(0.03, 0.14, 8.0), Vector3(-1.51, 0.82, 0), Vector3.ZERO, AMARILLO],
	["FranjaDerecha", "caja", Vector3(0.03, 0.14, 6.6), Vector3(1.51, 0.82, 0.7), Vector3.ZERO, AMARILLO],
	["BandaSuperiorIzquierda", "caja", Vector3(0.08, 0.35, 8.0), Vector3(-1.46, 2.175, 0), Vector3.ZERO, CREMA],
	["BandaSuperiorDerecha", "caja", Vector3(0.08, 0.35, 8.0), Vector3(1.46, 2.175, 0), Vector3.ZERO, CREMA],
	["Techo", "caja", Vector3(3.02, 0.12, 8.08), Vector3(0, 2.41, 0), Vector3.ZERO, BLANCO],
	["FrenteInferior", "caja", Vector3(3.0, 1.35, 0.08), Vector3(0, 0.325, -3.98), Vector3.ZERO, VERDE],
	["PilarFrenteIzquierdo", "caja", Vector3(0.14, 1.0, 0.08), Vector3(-1.43, 1.5, -3.98), Vector3.ZERO, CREMA],
	["PilarFrenteDerecho", "caja", Vector3(0.14, 1.0, 0.08), Vector3(1.43, 1.5, -3.98), Vector3.ZERO, CREMA],
	["BandaFrente", "caja", Vector3(3.0, 0.35, 0.08), Vector3(0, 2.175, -3.98), Vector3.ZERO, CREMA],
	["TraseraInferior", "caja", Vector3(3.0, 1.35, 0.08), Vector3(0, 0.325, 3.98), Vector3.ZERO, VERDE],
	["PilarAtrasIzquierdo", "caja", Vector3(0.3, 1.0, 0.08), Vector3(-1.35, 1.5, 3.98), Vector3.ZERO, CREMA],
	["PilarAtrasDerecho", "caja", Vector3(0.3, 1.0, 0.08), Vector3(1.35, 1.5, 3.98), Vector3.ZERO, CREMA],
	["BandaAtras", "caja", Vector3(3.0, 0.35, 0.08), Vector3(0, 2.175, 3.98), Vector3.ZERO, CREMA],
	["ParachoquesDelantero", "caja", Vector3(3.12, 0.26, 0.22), Vector3(0, -0.24, -4.08), Vector3.ZERO, GRIS],
	["ParachoquesTrasero", "caja", Vector3(3.12, 0.26, 0.22), Vector3(0, -0.24, 4.08), Vector3.ZERO, GRIS],
	["FaroIzquierdo", "esfera", Vector3(0.15, 0, 0), Vector3(-1.05, 0.5, -4.03), Vector3.ZERO, AMARILLO],
	["FaroDerecho", "esfera", Vector3(0.15, 0, 0), Vector3(1.05, 0.5, -4.03), Vector3.ZERO, AMARILLO],
	["CalaveraIzquierda", "esfera", Vector3(0.11, 0, 0), Vector3(-1.2, 0.55, 4.03), Vector3.ZERO, ROJO],
	["CalaveraDerecha", "esfera", Vector3(0.11, 0, 0), Vector3(1.2, 0.55, 4.03), Vector3.ZERO, ROJO],
	["Tablero", "caja", Vector3(2.86, 0.45, 0.45), Vector3(0, 0.78, -3.7), Vector3.ZERO, GRIS_OSCURO],
	["AsientoChofer", "caja", Vector3(0.6, 0.45, 0.6), Vector3(-0.85, 0.225, -2.75), Vector3.ZERO, VINO],
	["RespaldoChofer", "caja", Vector3(0.6, 0.8, 0.12), Vector3(-0.85, 0.85, -2.4), Vector3.ZERO, VINO],
	["Volante", "toro", Vector3(0.15, 0.2, 0), Vector3(-0.85, 1.1, -3.3), Vector3(60, 0, 0), NEGRO],
	["ColumnaVolante", "cilindro", Vector3(0.03, 0.45, 0), Vector3(-0.85, 0.95, -3.45), Vector3(60, 0, 0), NEGRO],
	["ArcoDelanteroIzquierdo", "caja", Vector3(0.5, 0.35, 1.1), Vector3(-1.2, 0.175, -2.1), Vector3.ZERO, GRIS_OSCURO],
	["ArcoDelanteroDerecho", "caja", Vector3(0.5, 0.35, 1.1), Vector3(1.2, 0.175, -2.05), Vector3.ZERO, GRIS_OSCURO],
	["ArcoTraseroIzquierdo", "caja", Vector3(0.5, 0.35, 1.1), Vector3(-1.2, 0.175, 2.6), Vector3.ZERO, GRIS_OSCURO],
	["ArcoTraseroDerecho", "caja", Vector3(0.5, 0.35, 1.1), Vector3(1.2, 0.175, 2.6), Vector3.ZERO, GRIS_OSCURO],
	["PasamanosIzquierdo", "cilindro", Vector3(0.025, 7.4, 0), Vector3(-0.5, 2.05, 0.2), Vector3(90, 0, 0), GRIS],
	["PasamanosDerecho", "cilindro", Vector3(0.025, 7.4, 0), Vector3(0.5, 2.05, 0.2), Vector3(90, 0, 0), GRIS],
	["PostePuerta", "cilindro", Vector3(0.03, 2.35, 0), Vector3(1.2, 1.175, -2.5), Vector3.ZERO, GRIS],
	["EscalonAlto", "caja", Vector3(0.32, 0.08, 1.0), Vector3(1.65, -0.2, -3.15), Vector3.ZERO, GRIS],
	["EscalonBajo", "caja", Vector3(0.32, 0.08, 1.0), Vector3(1.95, -0.43, -3.15), Vector3.ZERO, GRIS],
]

## Pilares de las ventanas laterales (posición z); del lado derecho dejan libre la puerta.
const PILARES_IZQUIERDA := [-3.94, -2.6, -1.3, 0.0, 1.3, 2.6, 3.94]
const PILARES_DERECHA := [-3.94, -3.7, -2.6, -1.3, 0.0, 1.3, 2.6, 3.94]
## Filas de asientos de pasajeros (posición z), a ambos lados del pasillo.
const FILAS_ASIENTOS := [-1.6, -0.6, 0.4, 1.4, 2.4, 3.3]
## Centro de los asientos (posición x): pegados a las paredes, dejan un pasillo de 1.2 m
## donde caben dos personas lado a lado.
const X_ASIENTOS := [-1.03, 1.03]


func _ready() -> void:
	var piezas := Node3D.new()
	piezas.name = "Piezas"
	add_child(piezas)
	for pieza in PIEZAS:
		var color: Color = color_principal if pieza[5] == VERDE else pieza[5]
		piezas.add_child(_crear_pieza(pieza[0], pieza[1], pieza[2], pieza[3], pieza[4], color))
	for z in PILARES_IZQUIERDA:
		piezas.add_child(_crear_pieza("PilarIzquierdo", "caja", Vector3(0.08, 1.0, 0.12), Vector3(-1.46, 1.5, z), Vector3.ZERO, CREMA))
	for z in PILARES_DERECHA:
		piezas.add_child(_crear_pieza("PilarDerecho", "caja", Vector3(0.08, 1.0, 0.12), Vector3(1.46, 1.5, z), Vector3.ZERO, CREMA))
	for z in FILAS_ASIENTOS:
		for x in X_ASIENTOS:
			piezas.add_child(_crear_pieza("Asiento", "caja", Vector3(0.85, 0.45, 0.5), Vector3(x, 0.225, z), Vector3.ZERO, VINO))
			piezas.add_child(_crear_pieza("Respaldo", "caja", Vector3(0.85, 0.6, 0.1), Vector3(x, 0.75, z + 0.25), Vector3.ZERO, VINO))
	EstiloToon.aplicar(piezas)


func _crear_pieza(nombre: String, forma: String, medidas: Vector3, posicion: Vector3, rotacion: Vector3, color: Color) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	malla.name = nombre
	match forma:
		"caja":
			var caja := BoxMesh.new()
			caja.size = medidas
			malla.mesh = caja
		"cilindro":
			var cilindro := CylinderMesh.new()
			cilindro.top_radius = medidas.x
			cilindro.bottom_radius = medidas.x
			cilindro.height = medidas.y
			cilindro.radial_segments = 12
			malla.mesh = cilindro
		"esfera":
			var esfera := SphereMesh.new()
			esfera.radius = medidas.x
			esfera.height = medidas.x * 2.0
			esfera.radial_segments = 12
			esfera.rings = 6
			malla.mesh = esfera
		"toro":
			var toro := TorusMesh.new()
			toro.inner_radius = medidas.x
			toro.outer_radius = medidas.y
			toro.rings = 16
			toro.ring_segments = 8
			malla.mesh = toro
	malla.position = posicion
	malla.rotation_degrees = rotacion
	malla.material_override = null
	malla.set_surface_override_material(0, EstiloToon.material(color, true, EstiloToon.ModoContorno.CAJA if forma == "caja" else EstiloToon.ModoContorno.NORMAL))
	return malla
