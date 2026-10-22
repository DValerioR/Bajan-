@tool
extends Node3D
## Carrocería del microbús hecha con formas básicas (DISEÑO.md, sección 3).
## Se genera al cargar la escena, también en el editor, a partir de la lista de piezas.
## Por fuera se ve el modelo del microbús (D60, modelos/camion/microbus.glb, lo prepara
## scripts/herramientas/microbus_blender.py): tapa estas piezas, que siguen siendo el interior y las
## colisiones, y su llanta se usa en las cuatro llantas del camión. Lo que solo se veía por fuera
## (franjas, defensas, faros, techo) se esconde. Sus ventanas tienen vidrio (D61): se ve a través de
## él por los dos lados y no choca, pero se rompe cuando alguien sale volando por ahí
## (`romper_vidrios`, lo llama InteriorCamion): saltan los pedazos y suena.
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

## El modelo de por fuera (D60); si no existe, se ve la carrocería de formas básicas.
const MODELO_EXTERIOR := "res://modelos/camion/microbus.glb"
## Piezas que solo se ven por fuera: con el modelo, se esconden (siguen chocando si eran cajas). Las
## paredes de abajo también: por dentro las tapa el forro.
const SOLO_POR_FUERA := ["FaldaIzquierda", "FaldaDerechaFrente", "FaldaDerechaAtras", "FrenteInferior", "TraseraInferior", "FranjaIzquierda", "FranjaDerecha", "Techo", "ParachoquesDelantero", "ParachoquesTrasero", "FaroIzquierdo", "FaroDerecho", "CalaveraIzquierda", "CalaveraDerecha"]
## El letrero de la ruta va en la caja del letrero del modelo, arriba del parabrisas.
const LETRERO_CON_MODELO := Vector3(0, 2.25, -4.09)
## Se rompen los pedazos de vidrio a menos de esto (m) de por donde salió alguien.
const RADIO_ROTURA := 0.6
## El modelo trae el hueco del parabrisas sin vidrio: se pone uno en el hueco del frente del
## interior, [medidas, centro] en coordenadas de la carrocería.
const PARABRISAS := [Vector3(2.72, 1.0, 0.012), Vector3(0, 1.5, -3.99)]

## Pedazos de vidrio del modelo: [{nodo, caja (AABB en coordenadas de la carrocería), roto}].
var vidrios: Array[Dictionary] = []
## Cuántas veces se rompió un vidrio (para las pruebas).
var vidrios_rotos: int = 0

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
	# Delante: ya no hay llanta abajo (D60), pero se quedan como estorbo (la tapa del motor): sin el de la
	# derecha, en los acelerones la gente se resbala hasta la puerta.
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
	["ForroFrente", "caja", Vector3(2.8, 0.95, 0.02), Vector3(0, 0.52, -3.93), Vector3.ZERO, GRIS_OSCURO, false],
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
	_poner_exterior(piezas)


## El modelo de por fuera y sus llantas (si existe). El rival lo tiñe de su color.
func _poner_exterior(piezas: Node3D) -> void:
	if not ResourceLoader.exists(MODELO_EXTERIOR):
		return
	var modelo: Node3D = (load(MODELO_EXTERIOR) as PackedScene).instantiate()
	var exterior := modelo.find_child("Exterior", true, false) as MeshInstance3D
	var llanta := modelo.find_child("Llanta", true, false) as MeshInstance3D
	if exterior == null:
		modelo.free()
		return
	var tinte := Color.WHITE if color_principal == VERDE else color_principal.lightened(0.35)
	var textura: Texture2D = null
	var original := exterior.get_active_material(0)
	if original is BaseMaterial3D:
		textura = original.albedo_texture
	var material := EstiloToon.material(tinte, true, EstiloToon.ModoContorno.NORMAL, textura)
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "Exterior"
	cuerpo.mesh = exterior.mesh
	cuerpo.set_surface_override_material(0, material)
	add_child(cuerpo)
	var vidrio := _material_vidrio()
	for pedazo: MeshInstance3D in modelo.find_children("Vidrio*", "MeshInstance3D", true, false):
		var nuevo := MeshInstance3D.new()
		nuevo.name = pedazo.name
		nuevo.mesh = pedazo.mesh
		nuevo.material_override = vidrio
		nuevo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(nuevo)
		vidrios.append({"nodo": nuevo, "caja": pedazo.mesh.get_aabb(), "roto": false})
	var parabrisas := MeshInstance3D.new()
	parabrisas.name = "Parabrisas"
	var lamina := BoxMesh.new()
	lamina.size = PARABRISAS[0]
	parabrisas.mesh = lamina
	parabrisas.position = PARABRISAS[1]
	parabrisas.material_override = vidrio
	parabrisas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(parabrisas)
	vidrios.append({"nodo": parabrisas, "caja": AABB(PARABRISAS[1] - PARABRISAS[0] * 0.5, PARABRISAS[0]), "roto": false, "parabrisas": true})
	for nombre in SOLO_POR_FUERA:
		var pieza := piezas.get_node_or_null(NodePath(nombre)) as Node3D
		if pieza != null:
			pieza.visible = false
	var letrero := get_node_or_null("Letrero") as Node3D
	if letrero != null:
		letrero.position = LETRERO_CON_MODELO
	# Las llantas: la del modelo en lugar del cilindro, con su cara hacia afuera.
	var ruedas := get_parent().get_node_or_null("Ruedas") if get_parent() != null else null
	if llanta != null and ruedas != null:
		for anclaje: Node3D in ruedas.get_children():
			var giro := anclaje.get_node_or_null("Llanta/Giro") as Node3D
			if giro == null or giro.has_node("LlantaModelo"):
				continue
			for vieja in giro.get_children():
				(vieja as Node3D).visible = false
			var nueva := MeshInstance3D.new()
			nueva.name = "LlantaModelo"
			nueva.mesh = llanta.mesh
			nueva.set_surface_override_material(0, material)
			if anclaje.position.x < 0.0:
				nueva.rotation.y = PI
			giro.add_child(nueva)
	modelo.free()


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


## Rompe los vidrios de cerca de `punto` (coordenadas de la carrocería), por donde algo salió o
## entró al camión. Por el hueco de la puerta no hay vidrio. Devuelve cuántos pedazos rompió.
func romper_vidrios(punto: Vector3) -> int:
	var rotos: Array[Dictionary] = []
	for v in vidrios:
		var caja: AABB = v.caja
		# Un pedazo que cruza de lado a lado (Tripo los junta así) no se rompe: lo tomaría todo.
		if v.roto or (caja.size.x > 1.0 and caja.size.z > 1.0):
			continue
		var cercano := punto.clamp(caja.position, caja.end)
		if cercano.distance_to(punto) < RADIO_ROTURA:
			rotos.append(v)
	if rotos.is_empty():
		return 0
	for v in rotos:
		v.roto = true
		(v.nodo as Node3D).visible = false
	vidrios_rotos += 1
	_pedazos(punto)
	return rotos.size()


## Rompe el parabrisas (el chofer salió arrancado del volante en un choque).
func romper_parabrisas() -> void:
	for v in vidrios:
		if v.get("parabrisas", false) and not v.roto:
			v.roto = true
			(v.nodo as Node3D).visible = false
			vidrios_rotos += 1
			_pedazos(PARABRISAS[1])


## Los pedazos que saltan (hacia afuera de ese lado) y el sonido del vidrio roto, en el mundo.
## `punto`: por donde pasó, en coordenadas de la carrocería.
func _pedazos(punto: Vector3) -> void:
	var mundo := get_tree().current_scene if get_tree() != null else null
	if mundo == null:
		return
	var centro := global_transform * punto
	var afuera := global_basis * _afuera_de(punto)
	var chispas := CPUParticles3D.new()
	chispas.name = "VidrioRoto"
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2(0.11, 0.08)
	# Los pedazos, más blancos que el vidrio entero, para que se vean volar.
	var pedazo := _material_vidrio()
	pedazo.albedo_color = Color(0.85, 0.95, 1.0, 0.8)
	pedazo.emission_enabled = true
	pedazo.emission = Color(0.35, 0.45, 0.5)
	cuadro.material = pedazo
	chispas.mesh = cuadro
	chispas.amount = 44
	chispas.lifetime = 1.6
	chispas.one_shot = true
	chispas.explosiveness = 0.95
	chispas.local_coords = false
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	chispas.emission_box_extents = Vector3(0.3, 0.3, 0.3)
	chispas.direction = afuera
	chispas.spread = 55.0
	chispas.initial_velocity_min = 2.0
	chispas.initial_velocity_max = 5.5
	chispas.gravity = Vector3(0, -9.8, 0)
	chispas.angular_velocity_min = -720.0
	chispas.angular_velocity_max = 720.0
	chispas.scale_amount_min = 0.5
	chispas.scale_amount_max = 1.6
	mundo.add_child(chispas)
	chispas.global_transform = Transform3D(global_basis, centro)
	chispas.emitting = true
	var sonido := AudioStreamPlayer3D.new()
	sonido.stream = Sintetizador.vidrio()
	sonido.unit_size = 8.0
	mundo.add_child(sonido)
	sonido.global_position = centro
	sonido.play()
	get_tree().create_timer(2.5).timeout.connect(func():
		chispas.queue_free()
		sonido.queue_free())


## Hacia dónde queda "afuera" de un punto de la carrocería: el costado, el frente o atrás.
static func _afuera_de(punto: Vector3) -> Vector3:
	if absf(punto.z) > 3.8:
		return Vector3(0, 0.3, signf(punto.z))
	return Vector3(signf(punto.x), 0.3, 0)


## Vidrio de las ventanas: transparente, un poco azulado y con brillo, visible por los dos lados.
static func _material_vidrio() -> StandardMaterial3D:
	var vidrio := StandardMaterial3D.new()
	vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vidrio.albedo_color = Color(0.62, 0.8, 0.92, 0.22)
	vidrio.roughness = 0.08
	vidrio.metallic_specular = 0.9
	vidrio.rim_enabled = true
	vidrio.rim = 0.4
	vidrio.cull_mode = BaseMaterial3D.CULL_DISABLED
	return vidrio


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
