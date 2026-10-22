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
const FORRO := Color(0.88, 0.82, 0.68)
const ALUMINIO := Color(0.78, 0.8, 0.84)
const CROMO := Color(0.82, 0.84, 0.88)
const HULE := Color(0.2, 0.2, 0.23)
const PLAFON := Color(0.92, 0.91, 0.87)
const PIEL := Color(0.86, 0.66, 0.5)
const AZUL := Color(0.18, 0.35, 0.8)
const MORADO := Color(0.55, 0.2, 0.95)
const ROSA := Color(0.95, 0.35, 0.65)

## Color de la carrocería (lo que va en verde): los rivales usan otro.
@export var color_principal: Color = VERDE
## Si arma los detalles del interior (forro, luces, adornos del chofer, letreros). El rival no, que
## solo se ve de lejos.
@export var con_interior: bool = true

## Piezas que van sin contorno (los tubos, que con él se ven gruesos).
const SIN_CONTORNO := ["PasamanosIzquierdo", "PasamanosDerecho", "PostePuerta"]

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
	["PasamanosIzquierdo", "cilindro", Vector3(0.025, 7.4, 0), Vector3(-0.5, 2.05, 0.2), Vector3(90, 0, 0), CROMO],
	["PasamanosDerecho", "cilindro", Vector3(0.025, 7.4, 0), Vector3(0.5, 2.05, 0.2), Vector3(90, 0, 0), CROMO],
	["PostePuerta", "cilindro", Vector3(0.03, 2.35, 0), Vector3(1.2, 1.175, -2.5), Vector3.ZERO, CROMO],
	["EscalonAlto", "caja", Vector3(0.32, 0.08, 1.0), Vector3(1.65, -0.2, -3.15), Vector3.ZERO, GRIS],
	["EscalonBajo", "caja", Vector3(0.32, 0.08, 1.0), Vector3(1.95, -0.43, -3.15), Vector3.ZERO, GRIS],
]

## Detalles del interior: solo se ven, no chocan (las colisiones salen de PIEZAS, GeometriaInterior).
## Mismo formato que PIEZAS; un séptimo valor en false los deja sin contorno.
const DETALLES := [
	# Forro de las paredes por dentro (beige), con zoclo oscuro abajo; del lado derecho deja la puerta.
	["ForroIzquierdo", "caja", Vector3(0.02, 0.95, 7.86), Vector3(-1.41, 0.52, 0), Vector3.ZERO, FORRO, false],
	["ForroDerecho", "caja", Vector3(0.02, 0.95, 6.5), Vector3(1.41, 0.52, 0.72), Vector3.ZERO, FORRO, false],
	["ForroDerechoFrente", "caja", Vector3(0.02, 0.95, 0.24), Vector3(1.41, 0.52, -3.82), Vector3.ZERO, FORRO, false],
	["ForroAtras", "caja", Vector3(2.8, 0.95, 0.02), Vector3(0, 0.52, 3.93), Vector3.ZERO, FORRO, false],
	["ZocloIzquierdo", "caja", Vector3(0.03, 0.16, 7.86), Vector3(-1.4, 0.08, 0), Vector3.ZERO, GRIS_OSCURO, false],
	["ZocloDerecho", "caja", Vector3(0.03, 0.16, 6.5), Vector3(1.4, 0.08, 0.72), Vector3.ZERO, GRIS_OSCURO, false],
	# Rieles de aluminio abajo y arriba de las ventanas.
	["RielIzquierdoAbajo", "caja", Vector3(0.07, 0.04, 7.86), Vector3(-1.39, 1.0, 0), Vector3.ZERO, ALUMINIO],
	["RielIzquierdoArriba", "caja", Vector3(0.07, 0.04, 7.86), Vector3(-1.39, 2.0, 0), Vector3.ZERO, ALUMINIO],
	["RielDerechoAbajo", "caja", Vector3(0.07, 0.04, 6.5), Vector3(1.39, 1.0, 0.72), Vector3.ZERO, ALUMINIO],
	["RielDerechoArriba", "caja", Vector3(0.07, 0.04, 7.86), Vector3(1.39, 2.0, 0), Vector3.ZERO, ALUMINIO],
	# Techo por dentro: plafón, una lámpara a lo largo y las tiras de luz morada de las orillas.
	["Plafon", "caja", Vector3(2.84, 0.03, 7.86), Vector3(0, 2.335, 0), Vector3.ZERO, PLAFON, false],
	["Lampara", "luz", Vector3(0.22, 0.03, 6.2), Vector3(0, 2.31, 0.3), Vector3.ZERO, Color(1.0, 0.96, 0.85)],
	["LucesIzquierda", "luz", Vector3(0.04, 0.04, 7.8), Vector3(-1.38, 2.3, 0), Vector3.ZERO, MORADO],
	["LucesDerecha", "luz", Vector3(0.04, 0.04, 7.8), Vector3(1.38, 2.3, 0), Vector3.ZERO, MORADO],
	# Tapete de hule en el pasillo, con sus rayas, y la orilla amarilla del escalón.
	["Tapete", "caja", Vector3(1.15, 0.012, 7.0), Vector3(0, 0.006, 0.45), Vector3.ZERO, HULE, false],
	["RayaTapete1", "caja", Vector3(0.025, 0.006, 7.0), Vector3(-0.3, 0.015, 0.45), Vector3.ZERO, GRIS, false],
	["RayaTapete2", "caja", Vector3(0.025, 0.006, 7.0), Vector3(0.0, 0.015, 0.45), Vector3.ZERO, GRIS, false],
	["RayaTapete3", "caja", Vector3(0.025, 0.006, 7.0), Vector3(0.3, 0.015, 0.45), Vector3.ZERO, GRIS, false],
	["OrillaEscalon", "caja", Vector3(0.06, 0.012, 1.0), Vector3(1.38, 0.006, -3.15), Vector3.ZERO, AMARILLO, false],
	# Lo del chofer: retrovisor con rosario, fleco de pompones en el parabrisas, la virgencita, el
	# velocímetro, el estéreo con su luz, la charola de las monedas y el tubo detrás de su asiento.
	["Retrovisor", "caja", Vector3(0.36, 0.1, 0.04), Vector3(0, 1.93, -3.88), Vector3.ZERO, NEGRO],
	["Espejo", "caja", Vector3(0.32, 0.07, 0.01), Vector3(0, 1.93, -3.857), Vector3.ZERO, Color(0.7, 0.8, 0.9), false],
	["Virgen", "cilindro", Vector3(0.045, 0.15, 0), Vector3(0.35, 1.08, -3.72), Vector3.ZERO, AZUL],
	["CabezaVirgen", "esfera", Vector3(0.03, 0, 0), Vector3(0.35, 1.18, -3.72), Vector3.ZERO, PIEL],
	["Aureola", "toro", Vector3(0.035, 0.045, 0), Vector3(0.35, 1.2, -3.74), Vector3(90, 0, 0), AMARILLO, false],
	["Velocimetro", "cilindro", Vector3(0.09, 0.02, 0), Vector3(-0.85, 1.02, -3.56), Vector3(60, 0, 0), BLANCO],
	["Aguja", "caja", Vector3(0.012, 0.07, 0.01), Vector3(-0.86, 1.04, -3.545), Vector3(-30, 0, 25), ROJO, false],
	["Estereo", "caja", Vector3(0.3, 0.09, 0.05), Vector3(0.15, 0.88, -3.47), Vector3.ZERO, NEGRO],
	["LuzEstereo", "luz", Vector3(0.24, 0.015, 0.01), Vector3(0.15, 0.9, -3.444), Vector3.ZERO, Color(0.2, 0.95, 1.0)],
	["Charola", "caja", Vector3(0.26, 0.05, 0.2), Vector3(-0.3, 1.03, -3.6), Vector3.ZERO, GRIS],
	["TuboChofer", "cilindro", Vector3(0.022, 0.85, 0), Vector3(-0.98, 1.3, -2.32), Vector3(0, 0, 90), CROMO, false],
]
## Pompones del fleco del parabrisas (colores que se van turnando) y cuentas del rosario.
const COLORES_FLECO := [ROJO, AMARILLO, VERDE, MORADO, ROSA, AZUL]
## Agarraderas que cuelgan de los pasamanos (posición z).
const AGARRADERAS_Z := [-2.0, -0.8, 0.4, 1.6, 2.8]
## Letreros pegados por dentro: [texto, posición, giro en y (grados), color de fondo, color de letra].
const LETREROS := [
	["PASAJE EXACTO\nPOR FAVOR", Vector3(0.75, 2.17, -3.93), 0.0, AMARILLO, NEGRO],
	["DIOS ES MI\nCOPILOTO", Vector3(-1.4, 2.17, -2.0), 90.0, BLANCO, AZUL],
	["NO ESCUPIR", Vector3(0, 0.75, 3.91), 180.0, ROJO, BLANCO],
	["ASIENTO\nRESERVADO", Vector3(1.4, 2.17, -1.6), -90.0, AZUL, BLANCO],
	["AVISE SU BAJADA\nCON TIEMPO", Vector3(-1.4, 2.17, 1.4), 90.0, AMARILLO, NEGRO],
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
			# Base de metal y cojín de vinil; el respaldo con su tubo para agarrarse arriba.
			piezas.add_child(_crear_pieza("Asiento", "caja", Vector3(0.85, 0.33, 0.5), Vector3(x, 0.165, z), Vector3.ZERO, GRIS_OSCURO))
			piezas.add_child(_crear_pieza("Cojin", "caja", Vector3(0.83, 0.12, 0.48), Vector3(x, 0.39, z), Vector3.ZERO, VINO))
			piezas.add_child(_crear_pieza("Respaldo", "caja", Vector3(0.85, 0.6, 0.1), Vector3(x, 0.75, z + 0.25), Vector3.ZERO, VINO))
			if con_interior:
				piezas.add_child(_crear_pieza("TuboRespaldo", "cilindro", Vector3(0.02, 0.8, 0), Vector3(x, 1.07, z + 0.25), Vector3(0, 0, 90), CROMO, false))
	if con_interior:
		_armar_interior(piezas)
	EstiloToon.aplicar(piezas)


## Los detalles del interior (DETALLES, el fleco, el rosario, las agarraderas y los letreros).
func _armar_interior(piezas: Node3D) -> void:
	# Las luces van aparte: el estilo toon no les toca su material que brilla.
	var luces := Node3D.new()
	luces.name = "Luces"
	add_child(luces)
	for d in DETALLES:
		var pieza := _crear_pieza(d[0], d[1], d[2], d[3], d[4], d[5], d.size() < 7 or d[6])
		(luces if d[1] == "luz" else piezas).add_child(pieza)
	# Fleco de pompones de colores a lo largo del parabrisas.
	for k in 15:
		var x := -1.3 + k * 2.6 / 14.0
		piezas.add_child(_crear_pieza("Pompon", "esfera", Vector3(0.04, 0, 0), Vector3(x, 1.96 - 0.02 * (k % 2), -3.91), Vector3.ZERO, COLORES_FLECO[k % COLORES_FLECO.size()]))
	# Rosario colgando del retrovisor: cuentas en V y una cruz.
	for k in 9:
		var t := k / 8.0
		var punto := Vector3(lerpf(-0.08, 0.08, t), 1.86 - 0.22 * (1.0 - absf(t * 2.0 - 1.0)), -3.87)
		piezas.add_child(_crear_pieza("Cuenta", "esfera", Vector3(0.012, 0, 0), punto, Vector3.ZERO, Color(0.45, 0.25, 0.12), false))
	piezas.add_child(_crear_pieza("Cruz", "caja", Vector3(0.015, 0.07, 0.01), Vector3(0, 1.56, -3.87), Vector3.ZERO, AMARILLO, false))
	piezas.add_child(_crear_pieza("CruzBrazo", "caja", Vector3(0.045, 0.015, 0.01), Vector3(0, 1.575, -3.87), Vector3.ZERO, AMARILLO, false))
	# Agarraderas: una cinta negra y un aro que cuelgan de cada pasamanos.
	for z in AGARRADERAS_Z:
		for x in [-0.5, 0.5]:
			piezas.add_child(_crear_pieza("Cinta", "caja", Vector3(0.025, 0.13, 0.015), Vector3(x, 1.97, z), Vector3.ZERO, NEGRO, false))
			piezas.add_child(_crear_pieza("Aro", "toro", Vector3(0.032, 0.042, 0), Vector3(x, 1.875, z), Vector3(0, 0, 90), AMARILLO, false))
	for l in LETREROS:
		piezas.add_child(_crear_letrero(l[0], l[1], l[2], l[3], l[4]))


## Letrero pegado en la pared: un fondo de color y el texto encima, viendo hacia +Z girado `giro`.
func _crear_letrero(texto: String, posicion: Vector3, giro: float, fondo: Color, letra: Color) -> Node3D:
	var letrero := Node3D.new()
	letrero.name = "Letrero" + texto.get_slice("\n", 0).capitalize().replace(" ", "")
	letrero.position = posicion
	letrero.rotation_degrees.y = giro
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	etiqueta.font_size = 40
	etiqueta.pixel_size = 0.003
	etiqueta.outline_size = 0
	etiqueta.modulate = letra
	etiqueta.position.z = 0.012
	letrero.add_child(etiqueta)
	var lineas := texto.count("\n") + 1
	var ancho := 0.0
	for linea in texto.split("\n"):
		ancho = maxf(ancho, linea.length() * 0.062 + 0.08)
	var placa := _crear_pieza("Placa", "caja", Vector3(ancho, 0.05 + lineas * 0.11, 0.01), Vector3.ZERO, Vector3.ZERO, fondo, false)
	letrero.add_child(placa)
	return letrero


func _crear_pieza(nombre: String, forma: String, medidas: Vector3, posicion: Vector3, rotacion: Vector3, color: Color, con_contorno: bool = true) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	malla.name = nombre
	match forma:
		"luz":
			# Una tira que brilla (no le da la sombra ni el toon).
			var tira := BoxMesh.new()
			tira.size = medidas
			malla.mesh = tira
			var brillo := StandardMaterial3D.new()
			brillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			brillo.albedo_color = color
			malla.material_override = brillo
			malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			malla.position = posicion
			malla.rotation_degrees = rotacion
			return malla
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
	con_contorno = con_contorno and not nombre in SIN_CONTORNO
	malla.set_surface_override_material(0, EstiloToon.material(color, con_contorno, EstiloToon.ModoContorno.CAJA if forma == "caja" else EstiloToon.ModoContorno.NORMAL))
	return malla
