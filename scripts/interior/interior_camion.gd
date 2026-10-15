class_name InteriorCamion
extends Node3D
## Interior del camión (DECISIONES.md, D35). Los cuerpos que van adentro (personajes y objetos)
## viven en un espacio de física propio (un SubViewport sin dibujo, con su propio mundo) donde
## el interior está quieto, en coordenadas del camión. Lo que hace el camión les llega como
## gravedad aparente y empujones con tope (MarcoInterior). Lo que se ve son "reflejos" colgados
## de la carrocería que copian su posición.
##
## Frontera con la calle: al salir por la puerta o una ventana, el cuerpo pasa al mundo con su
## velocidad real; al volver a entrar, regresa al espacio del interior. En el mundo, las paredes
## del camión son sólidas para que desde la calle solo se entre por la puerta o las ventanas.
## Cada cuerpo tiene un hijo "Visual" con lo que se dibuja; el jugador además tiene cámara.

## Margen (m) para decidir que algo ya salió del camión, y tiempo mínimo afuera antes de volver
## a entrar (s), para que nada rebote entre los dos espacios.
const MARGEN_SALIDA := 0.3
const TIEMPO_ANTES_DE_ENTRAR := 0.5

@export var camion: Camion
## Nodo del mundo donde viven los cuerpos que están en la calle.
@export var mundo: Node3D

var inercia: InerciaCamion
var parametros: ParametrosInterior
var espacio: SubViewport
## Cada registro: {cuerpo, camara, dentro, tiempo_fuera, reflejo}.
var registros: Array[Dictionary] = []

var _paredes_mundo: AnimatableBody3D
var _ancla: Node3D
var _marco_personajes: MarcoInterior
var _marco_objetos: MarcoInterior
var _marco_calle := MarcoMovimiento.new()


func _ready() -> void:
	process_physics_priority = 5
	parametros = ParametrosInterior.cargar()
	Config.recargado.connect(_al_recargar)
	inercia = InerciaCamion.new()
	inercia.name = "InerciaCamion"
	inercia.camion = camion
	add_child(inercia)

	# Paredes en el mundo, siguiendo al camión: para lo que está en la calle.
	_paredes_mundo = AnimatableBody3D.new()
	_paredes_mundo.name = "ParedesCamion"
	_paredes_mundo.sync_to_physics = true
	_llenar_paredes(_paredes_mundo)
	mundo.add_child.call_deferred(_paredes_mundo)

	# Espacio de física del interior, con las paredes quietas en coordenadas del camión.
	espacio = SubViewport.new()
	espacio.name = "EspacioInterior"
	espacio.own_world_3d = true
	espacio.size = Vector2i(4, 4)
	espacio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(espacio)
	var paredes := StaticBody3D.new()
	paredes.name = "ParedesInterior"
	_llenar_paredes(paredes)
	espacio.add_child(paredes)

	# Los reflejos cuelgan de la carrocería para ladearse con ella (balanceo visual).
	var carroceria: Node3D = camion.get_node("Carroceria")
	_ancla = Node3D.new()
	_ancla.name = "ReflejosInterior"
	_ancla.position = -carroceria.position
	carroceria.add_child(_ancla)
	_al_recargar()


func _llenar_paredes(cuerpo: CollisionObject3D) -> void:
	cuerpo.collision_layer = 4
	cuerpo.collision_mask = 0
	for datos in GeometriaInterior.formas():
		var forma := CollisionShape3D.new()
		forma.shape = datos[0]
		forma.transform = datos[1]
		cuerpo.add_child(forma)


func _al_recargar() -> void:
	parametros = ParametrosInterior.cargar()
	_marco_personajes = MarcoInterior.new(inercia, parametros, parametros.exageracion)
	_marco_objetos = MarcoInterior.new(inercia, parametros, parametros.exageracion_objetos)
	for registro in registros:
		if registro.dentro:
			registro.cuerpo.marco = _marco_de(registro.cuerpo)


func _marco_de(cuerpo: PhysicsBody3D) -> MarcoInterior:
	return _marco_personajes if cuerpo is CuerpoPersonaje else _marco_objetos


# --- Uso desde la escena ----------------------------------------------------

## Registra un cuerpo y lo coloca dentro del camión en `donde` (coordenadas del camión).
func agregar(cuerpo: PhysicsBody3D, camara: Camera3D, donde: Transform3D) -> void:
	var registro := {"cuerpo": cuerpo, "camara": camara, "dentro": false, "tiempo_fuera": 0.0, "reflejo": null}
	registros.append(registro)
	_meter(registro, donde, Vector3.ZERO)


## Registra un cuerpo que está en la calle (`donde` en coordenadas del mundo).
func agregar_en_calle(cuerpo: PhysicsBody3D, camara: Camera3D, donde: Transform3D) -> void:
	var registro := {"cuerpo": cuerpo, "camara": camara, "dentro": false, "tiempo_fuera": 0.0, "reflejo": null}
	registros.append(registro)
	_mover_a(cuerpo, mundo)
	cuerpo.global_transform = donde
	cuerpo.marco = _marco_calle
	if camara != null:
		_mover_a(camara, cuerpo.cabeza)
		camara.transform = Transform3D.IDENTITY
		camara.make_current()


## Vuelve a poner un cuerpo adentro, quieto (por ejemplo, al reiniciar).
func recolocar(cuerpo: PhysicsBody3D, donde: Transform3D) -> void:
	for registro in registros:
		if registro.cuerpo == cuerpo:
			if registro.dentro:
				_sacar(registro)
			_meter(registro, donde, Vector3.ZERO)


func esta_dentro(cuerpo: PhysicsBody3D) -> bool:
	for registro in registros:
		if registro.cuerpo == cuerpo:
			return registro.dentro
	return false


## Posición del cuerpo en coordenadas del camión, esté donde esté.
func posicion_local(cuerpo: PhysicsBody3D) -> Vector3:
	for registro in registros:
		if registro.cuerpo == cuerpo and registro.dentro:
			return cuerpo.position
	return camion.global_transform.affine_inverse() * cuerpo.global_position


# --- Frontera entre el interior y la calle ----------------------------------

func _physics_process(delta: float) -> void:
	_paredes_mundo.global_transform = camion.global_transform
	var limites_salida := GeometriaInterior.LIMITES.grow(MARGEN_SALIDA)
	var limites_entrada := GeometriaInterior.LIMITES.grow(-0.15)
	for registro in registros:
		var cuerpo: PhysicsBody3D = registro.cuerpo
		if registro.dentro:
			var centro := cuerpo.position + cuerpo.basis.y * 0.5
			if not limites_salida.has_point(centro):
				_sacar(registro)
		else:
			registro.tiempo_fuera += delta
			var local := camion.global_transform.affine_inverse() * cuerpo.global_transform
			var centro := local.origin + local.basis.y * 0.5
			if registro.tiempo_fuera > TIEMPO_ANTES_DE_ENTRAR and limites_entrada.has_point(centro):
				var relativa := camion.global_basis.inverse() * (_velocidad_de(cuerpo) - inercia.velocidad_en(cuerpo.global_position))
				_meter(registro, local, relativa)


func _process(_delta: float) -> void:
	for registro in registros:
		if registro.dentro and registro.reflejo != null:
			var cuerpo: PhysicsBody3D = registro.cuerpo
			registro.reflejo.transform = cuerpo.get_global_transform_interpolated()
			var camara: Camera3D = registro.camara
			if camara != null and camara.get_parent() == registro.reflejo:
				camara.transform = cuerpo.cabeza.transform


func _meter(registro: Dictionary, donde: Transform3D, velocidad_relativa: Vector3) -> void:
	var cuerpo: PhysicsBody3D = registro.cuerpo
	_mover_a(cuerpo, espacio)
	cuerpo.transform = donde
	if cuerpo is CharacterBody3D:
		cuerpo.velocity = velocidad_relativa
		cuerpo.orientar(cuerpo.giro_actual())
	elif cuerpo is RigidBody3D:
		cuerpo.linear_velocity = velocidad_relativa
		cuerpo.angular_velocity = Vector3.ZERO
	cuerpo.marco = _marco_de(cuerpo)
	cuerpo.reset_physics_interpolation()
	# Lo que se ve pasa a un reflejo dentro del camión.
	var reflejo := Node3D.new()
	reflejo.name = "Reflejo_" + cuerpo.name
	# El reflejo ya copia la posición interpolada del cuerpo en _process: no se interpola otra vez.
	reflejo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ancla.add_child(reflejo)
	reflejo.transform = donde
	var visual := cuerpo.get_node_or_null("Visual")
	if visual != null:
		_mover_a(visual, reflejo)
		visual.transform = Transform3D.IDENTITY
	var camara: Camera3D = registro.camara
	if camara != null:
		_mover_a(camara, reflejo)
		camara.transform = cuerpo.cabeza.transform
		camara.make_current()
	registro.reflejo = reflejo
	registro.dentro = true
	registro.tiempo_fuera = 0.0


func _sacar(registro: Dictionary) -> void:
	var cuerpo: PhysicsBody3D = registro.cuerpo
	var mundo_t := camion.global_transform * cuerpo.transform
	var base := camion.global_basis
	var velocidad_mundo := inercia.velocidad_en(mundo_t.origin) + base * _velocidad_de(cuerpo)
	_mover_a(cuerpo, mundo)
	cuerpo.global_transform = mundo_t
	if cuerpo is CharacterBody3D:
		cuerpo.velocity = velocidad_mundo
		cuerpo.orientar(cuerpo.giro_actual())
	elif cuerpo is RigidBody3D:
		cuerpo.linear_velocity = velocidad_mundo
		cuerpo.angular_velocity = camion.angular_velocity + base * cuerpo.angular_velocity
	cuerpo.marco = _marco_calle
	cuerpo.reset_physics_interpolation()
	var reflejo: Node3D = registro.reflejo
	if reflejo != null:
		var visual := reflejo.get_node_or_null("Visual")
		if visual != null:
			_mover_a(visual, cuerpo)
			visual.transform = Transform3D.IDENTITY
		var camara: Camera3D = registro.camara
		if camara != null:
			_mover_a(camara, cuerpo.cabeza)
			camara.transform = Transform3D.IDENTITY
			camara.make_current()
		reflejo.queue_free()
		registro.reflejo = null
	registro.dentro = false
	registro.tiempo_fuera = 0.0


# --- Utilidades ------------------------------------------------------------

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
