class_name Personaje
extends Node3D
## Figura visual de un personaje: carga el muñeco por piezas de modelos/personajes/<modelo>.scn
## y lo anima en código (sin esqueleto): caminar, sujetarse, cargar, tropezar y ladearse con
## los empujones. No tiene física; la lógica vive en CuerpoPersonaje y aquí solo se dibuja.
## Origen entre los pies, mirando a -Z (DECISIONES.md, D33).

const CARPETA := "res://modelos/personajes"

@export var modelo: String = "cobrador":
	set(valor):
		modelo = valor
		if is_inside_tree():
			_cargar()

var altura: float = 1.7
var altura_ojos: float = 1.55
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
	var escena := load(CARPETA.path_join(modelo + ".scn")) as PackedScene
	if escena == null:
		push_error("No existe el personaje: " + modelo)
		return
	_figura = escena.instantiate()
	add_child(_figura)
	EstiloToon.aplicar(_figura)
	altura = _figura.get_meta("altura", altura)
	altura_ojos = _figura.get_meta("altura_ojos", altura_ojos)
	_piezas.clear()
	for pieza in _figura.get_children():
		_piezas[pieza.name] = pieza
	if _piezas.has("PiernaIzquierda"):
		altura_cadera = (_piezas["PiernaIzquierda"] as Node3D).position.y
	if _piezas.has("BrazoDerecho"):
		mano_derecha = (_piezas["BrazoDerecho"] as Node3D).position + (_figura.get_meta("mano_derecha", Vector3.ZERO) as Vector3)


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
func animar(delta: float, velocidad: Vector3, empujon: Vector3, sujetado: bool, cargando: bool, tropezando: bool, en_el_aire: bool, sentado: bool = false) -> void:
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
