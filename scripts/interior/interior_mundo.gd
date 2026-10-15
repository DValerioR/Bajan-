class_name InteriorMundo
extends InteriorCamion
## Prototipo A: "interior en el mundo". Todos los cuerpos viven en el mundo normal. El interior
## del camión es una plataforma que se mueve (las paredes de la base), Godot lleva a los
## personajes con ella y solo se agregan los empujones por inercia. Los objetos sueltos
## se mueven con la física real: los arrastra la fricción del piso.

var _marco_personajes: MarcoInteriorMundo
var _marco_calle := MarcoMovimiento.new()


func _ready() -> void:
	super()
	_al_recargar()


func _al_recargar() -> void:
	_marco_personajes = MarcoInteriorMundo.new(inercia, parametros, parametros.exageracion)
	for registro in registros:
		if registro.dentro and registro.cuerpo is CuerpoPersonaje:
			registro.cuerpo.marco = _marco_personajes


func _meter(registro: Dictionary, donde: Transform3D, velocidad_relativa: Vector3) -> void:
	var cuerpo: PhysicsBody3D = registro.cuerpo
	_mover_a(cuerpo, mundo)
	cuerpo.global_transform = camion.global_transform * donde
	var base := camion.global_basis
	if cuerpo is CharacterBody3D:
		cuerpo.velocity = base * velocidad_relativa
		cuerpo.marco = _marco_personajes
	elif cuerpo is RigidBody3D:
		cuerpo.linear_velocity = inercia.velocidad_en(cuerpo.global_position) + base * velocidad_relativa
		cuerpo.angular_velocity = camion.angular_velocity
	if cuerpo.has_method("reset_physics_interpolation"):
		cuerpo.reset_physics_interpolation()
	var camara: Camera3D = registro.camara
	if camara != null:
		_mover_a(camara, cuerpo.cabeza)
		camara.transform = Transform3D.IDENTITY
		camara.make_current()
	registro.dentro = true


func _sacar(registro: Dictionary) -> void:
	if registro.cuerpo is CuerpoPersonaje:
		registro.cuerpo.marco = _marco_calle
	registro.dentro = false
	registro.tiempo_fuera = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	# Adentro o afuera solo cambia el marco: el cuerpo ya está en el mundo.
	var limites := GeometriaInterior.LIMITES.grow(0.2)
	for registro in registros:
		var cuerpo: PhysicsBody3D = registro.cuerpo
		var centro := camion.global_transform.affine_inverse() * (cuerpo.global_position + cuerpo.global_basis.y * 0.5)
		var dentro := limites.has_point(centro)
		if registro.dentro and not dentro:
			_sacar(registro)
		elif not registro.dentro and dentro:
			registro.dentro = true
			if cuerpo is CuerpoPersonaje:
				cuerpo.marco = _marco_personajes
