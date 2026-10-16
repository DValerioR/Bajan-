class_name Personaje
extends Node3D
## Figura visual de un personaje: carga el muñeco por piezas de modelos/personajes/<modelo>.glb
## y lo anima en código (sin esqueleto): caminar, sujetarse, cargar, tropezar y ladearse con
## los empujones. No tiene física; la lógica vive en CuerpoPersonaje y aquí solo se dibuja.
## Origen entre los pies, mirando a -Z (DECISIONES.md, D33 y D34).
##
## El .glb se puede editar en Blender: basta con que conserve las 6 piezas con su nombre
## (un sufijo como ".001" no importa) y el origen de cada una en su articulación. La estatura,
## el cuello, la cadera y las manos se sacan de las piezas al cargar.

const CARPETA := "res://modelos/personajes"
const PIEZAS := ["Cabeza", "Torso", "BrazoIzquierdo", "BrazoDerecho", "PiernaIzquierda", "PiernaDerecha"]

## Mallas con la normal suavizada para el contorno, ya calculadas (una por malla del modelo).
static var _mallas_contorno: Dictionary = {}

@export var modelo: String = "cobrador":
	set(valor):
		modelo = valor
		if is_inside_tree():
			_cargar()

var altura: float = 1.7
var altura_ojos: float = 1.55
var ancho: float = 0.8
## Altura de la cadera (donde se unen las piernas): para sentarlo a la altura del asiento.
var altura_cadera: float = 0.8
## Mano derecha en coordenadas de este nodo (para colocar lo que carga).
var mano_derecha := Vector3(0.3, 0.9, 0.0)

var _figura: Node3D
var _piezas: Dictionary = {}
var _fase: float = 0.0
var _inclinacion := Vector3.ZERO


func _ready() -> void:
	_cargar()


func _cargar() -> void:
	if _figura != null:
		_figura.queue_free()
	var escena := load(CARPETA.path_join(modelo + ".glb")) as PackedScene
	if escena == null:
		push_error("No existe el personaje: " + modelo)
		return
	# El .glb importado puede traer nodos de más (según cómo lo exporte Blender): se toman solo
	# las 6 piezas, con su lugar relativo al modelo, y se cuelgan de una figura limpia.
	var importado: Node3D = escena.instantiate()
	_figura = Node3D.new()
	_figura.name = "Figura"
	add_child(_figura)
	_piezas.clear()
	for nodo in importado.find_children("*", "MeshInstance3D", true, false):
		var nombre := _nombre_de_pieza(String(nodo.name))
		if nombre == "" or _piezas.has(nombre):
			continue
		var relativa := _relativa_a(nodo, importado)
		nodo.owner = null
		nodo.get_parent().remove_child(nodo)
		nodo.name = nombre
		nodo.transform = relativa
		nodo.mesh = _malla_con_contorno(nodo.mesh)
		_figura.add_child(nodo)
		_piezas[nombre] = nodo
	importado.free()
	EstiloToon.aplicar(_figura)
	_medir()


## Estatura, ancho, cuello, cadera y mano, sacados de las piezas (respeta lo editado en Blender).
func _medir() -> void:
	var caja := AABB()
	var primera := true
	for pieza: MeshInstance3D in _piezas.values():
		var suya := pieza.transform * pieza.get_aabb()
		caja = suya if primera else caja.merge(suya)
		primera = false
	altura = caja.end.y
	ancho = caja.size.x
	var cuello := altura * 0.7
	if _piezas.has("Cabeza"):
		cuello = (_piezas["Cabeza"] as Node3D).position.y
	altura_ojos = cuello + (altura - cuello) * 0.45
	if _piezas.has("PiernaIzquierda"):
		altura_cadera = (_piezas["PiernaIzquierda"] as Node3D).position.y
	if _piezas.has("BrazoDerecho"):
		# La mano es la punta de abajo del brazo, que cuelga en la pose original.
		var brazo: MeshInstance3D = _piezas["BrazoDerecho"]
		var su_caja := brazo.get_aabb()
		mano_derecha = brazo.transform * Vector3(su_caja.get_center().x, su_caja.position.y, su_caja.get_center().z)


static func _nombre_de_pieza(nombre_nodo: String) -> String:
	for pieza in PIEZAS:
		if nombre_nodo == pieza or nombre_nodo.begins_with(pieza + ".") or nombre_nodo.begins_with(pieza + "_"):
			return pieza
	return ""


static func _relativa_a(nodo: Node3D, raiz: Node3D) -> Transform3D:
	var t := nodo.transform
	var padre := nodo.get_parent()
	while padre != null and padre != raiz:
		if padre is Node3D:
			t = (padre as Node3D).transform * t
		padre = padre.get_parent()
	return t


## Copia de la malla con una normal suavizada (promedio de los vértices en la misma posición)
## guardada en el color de vértice: la usa el contorno para no abrirse en las costuras de la
## textura. Se calcula una vez por malla y no se guarda en el .glb.
static func _malla_con_contorno(malla: Mesh) -> Mesh:
	if malla == null or not malla is ArrayMesh:
		return malla
	var clave := malla.get_instance_id()
	if _mallas_contorno.has(clave):
		return _mallas_contorno[clave]
	var nueva := ArrayMesh.new()
	for s in malla.get_surface_count():
		var arreglos := malla.surface_get_arrays(s)
		var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		var normales: PackedVector3Array = arreglos[Mesh.ARRAY_NORMAL]
		var suma := {}
		for k in vertices.size():
			var punto := Vector3i((vertices[k] * 2000.0).round())
			suma[punto] = (suma.get(punto, Vector3.ZERO) as Vector3) + normales[k]
		var suaves := PackedColorArray()
		suaves.resize(vertices.size())
		for k in vertices.size():
			var n: Vector3 = (suma[Vector3i((vertices[k] * 2000.0).round())] as Vector3).normalized()
			suaves[k] = Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5)
		arreglos[Mesh.ARRAY_COLOR] = suaves
		nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos)
		nueva.surface_set_material(s, malla.surface_get_material(s))
	_mallas_contorno[clave] = nueva
	return nueva


## Cada pieza con su malla y su transformación relativa a este nodo, en la pose actual
## (para armar el ragdoll): [[nombre, MeshInstance3D, Transform3D], ...].
func piezas_con_transformacion() -> Array:
	var lista := []
	for nombre in _piezas:
		var pieza: MeshInstance3D = _piezas[nombre]
		if pieza.mesh != null:
			lista.append([nombre, pieza, _figura.transform * pieza.transform])
	return lista


## Muestra u oculta toda la figura (mientras el personaje anda hecho ragdoll).
func mostrar(visible_figura: bool) -> void:
	if _figura != null:
		_figura.visible = visible_figura


## Oculta la cabeza (para la cámara en primera persona del propio jugador).
func ocultar_cabeza(ocultar: bool) -> void:
	if _piezas.has("Cabeza"):
		_piezas["Cabeza"].visible = not ocultar


## Actualiza la pose. `velocidad` y `empujon` van en coordenadas de este nodo.
func animar(delta: float, velocidad: Vector3, empujon: Vector3, sujetado: bool, cargando: bool, tropezando: bool, en_el_aire: bool, sentado: bool = false, manejando: bool = false) -> void:
	if _piezas.is_empty():
		return
	var rapidez := Vector2(velocidad.x, velocidad.z).length()
	var paso := clampf(rapidez / 2.5, 0.0, 1.0)
	_fase = wrapf(_fase + delta * (4.0 + rapidez * 2.2), 0.0, TAU)
	var balanceo := sin(_fase) * deg_to_rad(38.0) * paso

	var pierna_izq := balanceo
	var pierna_der := -balanceo
	var brazo_izq := Vector3(-balanceo * 0.8, 0.0, 0.0)
	var brazo_der := Vector3(balanceo * 0.8, 0.0, 0.0)
	var cabeza := Vector3.ZERO

	if en_el_aire:
		pierna_izq = deg_to_rad(-25.0)
		pierna_der = deg_to_rad(15.0)
		brazo_izq = Vector3(0.0, 0.0, deg_to_rad(-60.0))
		brazo_der = Vector3(0.0, 0.0, deg_to_rad(60.0))
	if tropezando:
		# Aspavientos: brazos girando y piernas trastabillando.
		var agitar := sin(_fase * 3.0)
		brazo_izq = Vector3(deg_to_rad(100.0 + 60.0 * agitar), 0.0, deg_to_rad(-40.0))
		brazo_der = Vector3(deg_to_rad(100.0 - 60.0 * agitar), 0.0, deg_to_rad(40.0))
		pierna_izq = deg_to_rad(25.0) * agitar
		pierna_der = -pierna_izq
		cabeza = Vector3(deg_to_rad(15.0) * agitar, 0.0, 0.0)
	if cargando:
		brazo_izq = Vector3(deg_to_rad(75.0), 0.0, deg_to_rad(10.0))
		brazo_der = Vector3(deg_to_rad(75.0), 0.0, deg_to_rad(-10.0))
	if sentado:
		# Piernas al frente y manos sobre las rodillas.
		pierna_izq = deg_to_rad(85.0)
		pierna_der = deg_to_rad(85.0)
		brazo_izq = Vector3(deg_to_rad(35.0), 0.0, 0.0)
		brazo_der = Vector3(deg_to_rad(35.0), 0.0, 0.0)
	if manejando:
		# Las dos manos al volante, que se mueve con la vuelta (empujon.x trae el volante).
		brazo_izq = Vector3(deg_to_rad(70.0 + 12.0 * empujon.x), 0.0, deg_to_rad(12.0))
		brazo_der = Vector3(deg_to_rad(70.0 - 12.0 * empujon.x), 0.0, deg_to_rad(-12.0))
	if sujetado:
		# Brazo derecho arriba, agarrado del pasamanos o del respaldo.
		brazo_der = Vector3(deg_to_rad(160.0), 0.0, deg_to_rad(-10.0))

	var t := 1.0 - exp(-14.0 * delta)
	_girar("PiernaIzquierda", Vector3(pierna_izq, 0.0, 0.0), t)
	_girar("PiernaDerecha", Vector3(pierna_der, 0.0, 0.0), t)
	_girar("BrazoIzquierdo", brazo_izq, t)
	_girar("BrazoDerecho", brazo_der, t)
	_girar("Cabeza", cabeza, t)

	# Todo el cuerpo se ladea hacia donde lo empuja el camión (frente = -Z).
	var objetivo := Vector3(empujon.z, 0.0, -empujon.x) * deg_to_rad(2.2)
	objetivo = objetivo.limit_length(deg_to_rad(25.0))
	_inclinacion = _inclinacion.lerp(objetivo, 1.0 - exp(-6.0 * delta))
	_figura.rotation = Vector3(_inclinacion.x, 0.0, _inclinacion.z)


func _girar(nombre: String, objetivo: Vector3, t: float) -> void:
	if _piezas.has(nombre):
		var pieza: Node3D = _piezas[nombre]
		pieza.rotation = pieza.rotation.lerp(objetivo, t)
