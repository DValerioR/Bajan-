class_name InteriorCamion
extends Node3D
## Interior del camión (DECISIONES.md, D35). Las entidades que van adentro (personajes, objetos,
## ragdolls) viven en un espacio de física propio (un SubViewport sin dibujo, con su propio mundo)
## donde el interior está quieto, en coordenadas del camión. Lo que hace el camión les llega como
## gravedad aparente y empujones con tope (MarcoInterior). Lo que se ve son "reflejos" colgados de
## la carrocería que copian la posición de cada cuerpo.
##
## Frontera con la calle: al salir por la puerta o una ventana, la entidad pasa al mundo con su
## velocidad real; al volver a entrar, regresa al espacio del interior. En el mundo, las paredes
## del camión son sólidas para que desde la calle solo se entre por la puerta o las ventanas.
##
## Una entidad es un cuerpo físico, o un nodo con varios (un ragdoll) que ofrece:
##   cuerpos() -> Array: sus cuerpos físicos;  centro() -> Vector3: para saber si está adentro;
##   nodo_cabeza() -> Node3D: lo que sigue la cámara (opcional).
## Cada cuerpo físico puede tener un hijo "Visual" con lo que se dibuja.

## Margen (m) para decidir que algo ya salió del camión, y tiempo mínimo afuera antes de volver
## a entrar (s), para que nada rebote entre los dos espacios.
const MARGEN_SALIDA := 0.3
const TIEMPO_ANTES_DE_ENTRAR := 0.5

@export var camion: Camion
## Nodo del mundo donde viven las entidades que están en la calle.
@export var mundo: Node3D

var inercia: InerciaCamion
var parametros: ParametrosInterior
var espacio: SubViewport
## Cada registro: {entidad, camara, dentro, tiempo_fuera, reflejos: [[cuerpo, reflejo], ...]}.
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
		_asignar_marcos(registro)


# --- Uso desde la escena ----------------------------------------------------

## Registra una entidad y la coloca dentro del camión en `donde` (coordenadas del camión).
func agregar(entidad: Node3D, camara: Camera3D, donde: Transform3D) -> void:
	var registro := _nuevo_registro(entidad, camara)
	_mover_a(entidad, espacio)
	entidad.transform = donde
	_poner_dentro(registro, true)
	for cuerpo in _cuerpos(entidad):
		_poner_velocidad(cuerpo, Vector3.ZERO, Vector3.ZERO)


## Registra una entidad que está en la calle (`donde` en coordenadas del mundo).
func agregar_en_calle(entidad: Node3D, camara: Camera3D, donde: Transform3D) -> void:
	var registro := _nuevo_registro(entidad, camara)
	_mover_a(entidad, mundo)
	entidad.global_transform = donde
	_poner_dentro(registro, false)


## Registra una entidad que ya está colocada en uno de los dos espacios (por ejemplo, un ragdoll
## recién armado donde estaba su personaje).
func agregar_tal_cual(entidad: Node3D, camara: Camera3D, dentro: bool) -> void:
	_poner_dentro(_nuevo_registro(entidad, camara), dentro)


## Deja de seguir a una entidad (sus visuales regresan a sus cuerpos).
func quitar(entidad: Node3D) -> void:
	for registro in registros:
		if registro.entidad == entidad:
			_quitar_reflejos(registro)
			registros.erase(registro)
			return


## Le pasa la cámara de una entidad a otra (del personaje a su ragdoll y de regreso).
func pasar_camara(de: Node3D, a: Node3D) -> void:
	var camara: Camera3D = null
	for registro in registros:
		if registro.entidad == de:
			camara = registro.camara
			registro.camara = null
	for registro in registros:
		if registro.entidad == a:
			registro.camara = camara


## Vuelve a poner una entidad adentro, quieta (por ejemplo, al reiniciar).
func recolocar(entidad: Node3D, donde: Transform3D) -> void:
	for registro in registros:
		if registro.entidad == entidad:
			if not registro.dentro:
				_cambiar_espacio(registro, true)
			entidad.transform = donde
			for cuerpo in _cuerpos(entidad):
				_poner_velocidad(cuerpo, Vector3.ZERO, Vector3.ZERO)
				cuerpo.reset_physics_interpolation()
			if entidad.has_method("al_cambiar_espacio"):
				entidad.al_cambiar_espacio()


## Pasa una entidad al espacio indicado (adentro o la calle), conservando dónde está y su velocidad.
func llevar_a(entidad: Node3D, dentro: bool) -> void:
	for registro in registros:
		if registro.entidad == entidad and registro.dentro != dentro:
			_cambiar_espacio(registro, dentro)


func esta_dentro(entidad: Node3D) -> bool:
	for registro in registros:
		if registro.entidad == entidad:
			return registro.dentro
	return false


## Posición de una entidad en coordenadas del camión, esté donde esté.
func posicion_local(entidad: Node3D) -> Vector3:
	var posicion := _posicion_de(entidad)
	if esta_dentro(entidad):
		return posicion
	return camion.global_transform.affine_inverse() * posicion


## Pasa un punto del espacio de la entidad a coordenadas del camión (y al revés).
func a_local(entidad: Node3D, punto: Vector3) -> Vector3:
	return punto if esta_dentro(entidad) else camion.global_transform.affine_inverse() * punto


func desde_local(entidad: Node3D, punto_local: Vector3) -> Vector3:
	return punto_local if esta_dentro(entidad) else camion.global_transform * punto_local


# --- Frontera entre el interior y la calle ----------------------------------

func _physics_process(delta: float) -> void:
	_paredes_mundo.global_transform = camion.global_transform
	var limites_salida := GeometriaInterior.LIMITES.grow(MARGEN_SALIDA)
	var limites_entrada := GeometriaInterior.LIMITES.grow(-0.15)
	for registro in registros.duplicate():
		if not is_instance_valid(registro.entidad):
			registros.erase(registro)
			continue
		var centro := _centro(registro.entidad)
		if registro.dentro:
			if not limites_salida.has_point(centro):
				_cambiar_espacio(registro, false)
		else:
			registro.tiempo_fuera += delta
			var local := camion.global_transform.affine_inverse() * centro
			if registro.tiempo_fuera > TIEMPO_ANTES_DE_ENTRAR and limites_entrada.has_point(local):
				_cambiar_espacio(registro, true)


func _process(_delta: float) -> void:
	for registro in registros:
		if not is_instance_valid(registro.entidad):
			continue
		for par in registro.reflejos:
			par[1].transform = (par[0] as Node3D).get_global_transform_interpolated()
		var camara: Camera3D = registro.camara
		var cabeza := _cabeza(registro.entidad)
		if camara != null and cabeza != null:
			var vista := cabeza.get_global_transform_interpolated()
			camara.global_transform = _ancla.global_transform * vista if registro.dentro else vista


func _nuevo_registro(entidad: Node3D, camara: Camera3D) -> Dictionary:
	var registro := {"entidad": entidad, "camara": camara, "dentro": false, "tiempo_fuera": 0.0, "reflejos": []}
	registros.append(registro)
	if camara != null:
		_mover_a(camara, self)
		camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camara.make_current()
	return registro


func _cambiar_espacio(registro: Dictionary, a_dentro: bool) -> void:
	var entidad: Node3D = registro.entidad
	var transformacion := camion.global_transform
	var base := camion.global_basis
	# Primero se calcula dónde y a qué velocidad queda cada cuerpo en el otro espacio.
	var estados := []
	for cuerpo: PhysicsBody3D in _cuerpos(entidad):
		var t: Transform3D = cuerpo.global_transform
		var v := _velocidad_de(cuerpo)
		var w: Vector3 = cuerpo.angular_velocity if cuerpo is RigidBody3D else Vector3.ZERO
		if a_dentro:
			var punto_mundo := t.origin
			t = transformacion.affine_inverse() * t
			v = base.inverse() * (v - inercia.velocidad_en(punto_mundo))
			w = base.inverse() * (w - camion.angular_velocity)
		else:
			t = transformacion * t
			v = inercia.velocidad_en(t.origin) + base * v
			w = camion.angular_velocity + base * w
		estados.append([cuerpo, t, v, w])
	var origen_entidad := transformacion.affine_inverse() * entidad.global_transform if a_dentro else transformacion * entidad.global_transform
	_quitar_reflejos(registro)
	_mover_a(entidad, espacio if a_dentro else mundo)
	entidad.global_transform = origen_entidad
	for estado in estados:
		var cuerpo: PhysicsBody3D = estado[0]
		cuerpo.global_transform = estado[1]
		_poner_velocidad(cuerpo, estado[2], estado[3])
		cuerpo.reset_physics_interpolation()
	_poner_dentro(registro, a_dentro)
	if entidad.has_method("al_cambiar_espacio"):
		entidad.al_cambiar_espacio()


func _poner_dentro(registro: Dictionary, dentro: bool) -> void:
	registro.dentro = dentro
	registro.tiempo_fuera = 0.0
	_asignar_marcos(registro)
	if dentro:
		# Lo que se ve de cada cuerpo pasa a un reflejo dentro del camión.
		for cuerpo in _cuerpos(registro.entidad):
			var visual: Node = (cuerpo as Node).get_node_or_null("Visual")
			if visual == null:
				continue
			var reflejo := Node3D.new()
			reflejo.name = "Reflejo_" + cuerpo.name
			# El reflejo ya copia la posición interpolada en _process: no se interpola otra vez.
			reflejo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			_ancla.add_child(reflejo)
			reflejo.transform = cuerpo.global_transform
			_mover_a(visual, reflejo)
			visual.transform = Transform3D.IDENTITY
			registro.reflejos.append([cuerpo, reflejo])


func _quitar_reflejos(registro: Dictionary) -> void:
	for par in registro.reflejos:
		var cuerpo: Node3D = par[0]
		var reflejo: Node3D = par[1]
		var visual := reflejo.get_node_or_null("Visual")
		if visual != null and is_instance_valid(cuerpo):
			_mover_a(visual, cuerpo)
			visual.transform = Transform3D.IDENTITY
		reflejo.queue_free()
	registro.reflejos.clear()


func _asignar_marcos(registro: Dictionary) -> void:
	for cuerpo in _cuerpos(registro.entidad):
		if not "marco" in cuerpo:
			continue
		if not registro.dentro:
			cuerpo.marco = _marco_calle
		elif cuerpo is CuerpoPersonaje:
			cuerpo.marco = _marco_personajes
		else:
			cuerpo.marco = _marco_objetos


# --- Utilidades ------------------------------------------------------------

static func _cuerpos(entidad: Node3D) -> Array:
	if entidad.has_method("cuerpos"):
		return entidad.cuerpos()
	return [entidad]


static func _centro(entidad: Node3D) -> Vector3:
	if entidad.has_method("centro"):
		return entidad.centro()
	return entidad.global_position + entidad.global_basis.y * 0.5


static func _posicion_de(entidad: Node3D) -> Vector3:
	if entidad.has_method("centro"):
		return entidad.centro()
	return entidad.global_position


static func _cabeza(entidad: Node3D) -> Node3D:
	if entidad.has_method("nodo_cabeza"):
		return entidad.nodo_cabeza()
	return entidad.get("cabeza")


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


static func _poner_velocidad(cuerpo: PhysicsBody3D, lineal: Vector3, angular: Vector3) -> void:
	if cuerpo is CharacterBody3D:
		cuerpo.velocity = lineal
	elif cuerpo is RigidBody3D:
		cuerpo.linear_velocity = lineal
		cuerpo.angular_velocity = angular
