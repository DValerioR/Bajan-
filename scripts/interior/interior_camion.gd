class_name InteriorCamion
extends Node3D
## Base de los dos prototipos del interior (DECISIONES.md, D1). Registra los cuerpos que viajan
## en el camión (personajes y objetos), sabe si cada uno está adentro o afuera y pone las
## paredes del camión en el mundo para que desde la calle no se puedan atravesar.
## Cada cuerpo tiene un hijo "Visual" con lo que se dibuja; el jugador además tiene cámara.

@export var camion: Camion
## Nodo del mundo donde viven los cuerpos que están en la calle.
@export var mundo: Node3D

var inercia: InerciaCamion
var parametros: ParametrosInterior
## Cada registro: {cuerpo, camara, dentro, tiempo_fuera, ...}.
var registros: Array[Dictionary] = []

var _paredes: AnimatableBody3D


func _ready() -> void:
	process_physics_priority = 5
	parametros = ParametrosInterior.cargar()
	Config.recargado.connect(func(): parametros = ParametrosInterior.cargar(); _al_recargar())
	inercia = InerciaCamion.new()
	inercia.name = "InerciaCamion"
	inercia.camion = camion
	add_child(inercia)
	_paredes = AnimatableBody3D.new()
	_paredes.name = "ParedesCamion"
	_paredes.collision_layer = 4
	_paredes.collision_mask = 0
	_paredes.sync_to_physics = true
	for datos in GeometriaInterior.formas():
		var forma := CollisionShape3D.new()
		forma.shape = datos[0]
		forma.transform = datos[1]
		_paredes.add_child(forma)
	mundo.add_child.call_deferred(_paredes)


## Registra un cuerpo y lo coloca dentro del camión en `donde` (coordenadas del camión).
func agregar(cuerpo: PhysicsBody3D, camara: Camera3D, donde: Transform3D) -> void:
	var registro := {"cuerpo": cuerpo, "camara": camara, "dentro": false, "tiempo_fuera": 0.0}
	registros.append(registro)
	_meter(registro, donde, Vector3.ZERO)


## Vuelve a poner un cuerpo adentro, quieto (por ejemplo, al reiniciar).
func recolocar(cuerpo: PhysicsBody3D, donde: Transform3D) -> void:
	for registro in registros:
		if registro.cuerpo == cuerpo:
			if registro.dentro:
				_sacar(registro)
			_meter(registro, donde, Vector3.ZERO)
			if cuerpo is CharacterBody3D:
				cuerpo.velocity = Vector3.ZERO


func esta_dentro(cuerpo: PhysicsBody3D) -> bool:
	for registro in registros:
		if registro.cuerpo == cuerpo:
			return registro.dentro
	return false


## Posición del cuerpo en coordenadas del camión, esté donde esté.
func posicion_local(cuerpo: PhysicsBody3D) -> Vector3:
	for registro in registros:
		if registro.cuerpo == cuerpo and registro.dentro:
			return _posicion_dentro(registro)
	return camion.global_transform.affine_inverse() * cuerpo.global_position


func _physics_process(_delta: float) -> void:
	_paredes.global_transform = camion.global_transform


# --- Lo que cambia entre prototipos ----------------------------------------

func _meter(_registro: Dictionary, _donde: Transform3D, _velocidad_relativa: Vector3) -> void:
	pass


func _sacar(_registro: Dictionary) -> void:
	pass


func _posicion_dentro(registro: Dictionary) -> Vector3:
	return camion.global_transform.affine_inverse() * (registro.cuerpo as Node3D).global_position


func _al_recargar() -> void:
	pass


# --- Utilidades ------------------------------------------------------------

## Cambia un nodo de padre conservando su lugar en el árbol de escena.
static func _mover_a(nodo: Node, nuevo_padre: Node) -> void:
	if nodo.get_parent() == nuevo_padre:
		return
	if nodo.get_parent() != null:
		nodo.get_parent().remove_child(nodo)
	nuevo_padre.add_child(nodo)


static func _velocidad_de(cuerpo: PhysicsBody3D) -> Vector3:
	if cuerpo is CharacterBody3D:
		return cuerpo.velocity
	if cuerpo is RigidBody3D:
		return cuerpo.linear_velocity
	return Vector3.ZERO
