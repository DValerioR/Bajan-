class_name InteriorLocal
extends InteriorCamion
## Prototipo B: "interior separado". Los cuerpos que van adentro viven en un espacio de física
## propio (un SubViewport sin dibujo, con su propio mundo) donde el interior está quieto, en
## coordenadas del camión. Lo que hace el camión les llega como gravedad aparente y empujones
## con tope (MarcoInteriorLocal). Lo que se ve son "reflejos" colgados de la carrocería que copian
## su posición. Al salir por la puerta o una ventana, el cuerpo pasa al mundo con su velocidad
## real; al volver a entrar, regresa al espacio del interior.

## Margen (m) para decidir que algo ya salió del camión, y tiempo mínimo afuera antes de volver
## a entrar (s), para que nada rebote entre los dos espacios.
const MARGEN_SALIDA := 0.3
const TIEMPO_ANTES_DE_ENTRAR := 0.5

var espacio: SubViewport
var _ancla: Node3D
var _marco_personajes: MarcoInteriorLocal
var _marco_objetos: MarcoInteriorLocal
var _marco_calle := MarcoMovimiento.new()


func _ready() -> void:
	super()
	espacio = SubViewport.new()
	espacio.name = "EspacioInterior"
	espacio.own_world_3d = true
	espacio.size = Vector2i(4, 4)
	espacio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(espacio)
	var paredes := StaticBody3D.new()
	paredes.name = "ParedesInterior"
	paredes.collision_layer = 4
	paredes.collision_mask = 0
	for datos in GeometriaInterior.formas():
		var forma := CollisionShape3D.new()
		forma.shape = datos[0]
		forma.transform = datos[1]
		paredes.add_child(forma)
	espacio.add_child(paredes)
	# Los reflejos cuelgan de la carrocería para ladearse con ella (balanceo visual).
	var carroceria: Node3D = camion.get_node("Carroceria")
	_ancla = Node3D.new()
	_ancla.name = "ReflejosInterior"
	_ancla.position = -carroceria.position
	carroceria.add_child(_ancla)
	_al_recargar()


func _al_recargar() -> void:
	_marco_personajes = MarcoInteriorLocal.new(inercia, parametros, parametros.exageracion)
	_marco_objetos = MarcoInteriorLocal.new(inercia, parametros, parametros.exageracion_objetos)
	for registro in registros:
		if registro.dentro:
			registro.cuerpo.marco = _marco_personajes if registro.cuerpo is CuerpoPersonaje else _marco_objetos


func _meter(registro: Dictionary, donde: Transform3D, velocidad_relativa: Vector3) -> void:
	var cuerpo: PhysicsBody3D = registro.cuerpo
	_mover_a(cuerpo, espacio)
	cuerpo.transform = donde
	if cuerpo is CharacterBody3D:
		cuerpo.velocity = velocidad_relativa
	elif cuerpo is RigidBody3D:
		cuerpo.linear_velocity = velocidad_relativa
		cuerpo.angular_velocity = Vector3.ZERO
	cuerpo.marco = _marco_personajes if cuerpo is CuerpoPersonaje else _marco_objetos
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
	var local := cuerpo.transform
	var mundo_t := camion.global_transform * local
	var base := camion.global_basis
	var velocidad_local := _velocidad_de(cuerpo)
	var velocidad_mundo := inercia.velocidad_en(mundo_t.origin) + base * velocidad_local
	_mover_a(cuerpo, mundo)
	cuerpo.global_transform = mundo_t
	if cuerpo is CharacterBody3D:
		cuerpo.velocity = velocidad_mundo
	elif cuerpo is RigidBody3D:
		cuerpo.linear_velocity = velocidad_mundo
		cuerpo.angular_velocity = camion.angular_velocity + base * cuerpo.angular_velocity
	cuerpo.marco = _marco_calle
	cuerpo.reset_physics_interpolation()
	var reflejo: Node3D = registro.get("reflejo")
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


func _posicion_dentro(registro: Dictionary) -> Vector3:
	return (registro.cuerpo as Node3D).position


func _physics_process(delta: float) -> void:
	super(delta)
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
		if registro.dentro and registro.get("reflejo") != null:
			var cuerpo: PhysicsBody3D = registro.cuerpo
			registro.reflejo.transform = cuerpo.get_global_transform_interpolated()
			var camara: Camera3D = registro.camara
			if camara != null and camara.get_parent() == registro.reflejo:
				camara.transform = cuerpo.cabeza.transform
