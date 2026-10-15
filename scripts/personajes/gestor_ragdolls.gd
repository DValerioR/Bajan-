class_name GestorRagdolls
extends Node
## Convierte personajes en ragdoll cuando lo piden (golpe fuerte, frenazo sin sujetarse) y los
## vuelve a levantar. Respeta el tope de ragdolls activos al mismo tiempo (D4): si ya hay
## demasiados, el personaje solo tropieza. El ragdoll se arma en el mismo espacio donde estaba
## el personaje (adentro o en la calle) y queda registrado en el interior del camión, así que
## puede salir volando por una ventana. Al levantarse, el personaje aparece donde quedó el torso.

signal desplomado(cuerpo: CuerpoPersonaje)
signal levantado(cuerpo: CuerpoPersonaje)

@export var interior: InteriorCamion

## Cada uno: {cuerpo, ragdoll, tiempo}.
var activos: Array[Dictionary] = []
## Cuántas veces alguien se ha vuelto ragdoll (lo usan las pruebas).
var total_desplomes: int = 0


## Conecta a un personaje para que pueda caer como ragdoll.
func vigilar(cuerpo: CuerpoPersonaje) -> void:
	cuerpo.pide_desplomarse.connect(desplomar.bind(cuerpo))


func desplomar(empujon: Vector3, cuerpo: CuerpoPersonaje) -> bool:
	var p := interior.parametros
	if cuerpo.desplomado or cuerpo.visual == null:
		return false
	if activos.size() >= p.max_ragdolls:
		cuerpo.tropezando = p.duracion_tropiezo
		return false
	var dentro := interior.esta_dentro(cuerpo)
	var espacio := cuerpo.get_parent()
	var masa := p.masa_ragdoll * pow(cuerpo.altura / 1.7, 2.0)
	var ragdoll := Ragdoll.desde_figura(cuerpo.visual, cuerpo.global_transform, masa, p.columpio_ragdoll, p.giro_ragdoll)
	ragdoll.name = "Ragdoll_" + cuerpo.name
	espacio.add_child(ragdoll)
	ragdoll.soltar(cuerpo.velocity, empujon)
	cuerpo.desplomar()
	interior.agregar_tal_cual(ragdoll, null, dentro)
	interior.pasar_camara(cuerpo, ragdoll)
	activos.append({"cuerpo": cuerpo, "ragdoll": ragdoll, "tiempo": 0.0})
	total_desplomes += 1
	desplomado.emit(cuerpo)
	return true


func _physics_process(delta: float) -> void:
	var p := interior.parametros
	for activo in activos.duplicate():
		activo.tiempo += delta
		var ragdoll: Ragdoll = activo.ragdoll
		if (activo.tiempo > p.tiempo_minimo_ragdoll and ragdoll.quieto()) or activo.tiempo > p.tiempo_maximo_ragdoll:
			_levantar(activo)


func _levantar(activo: Dictionary) -> void:
	var cuerpo: CuerpoPersonaje = activo.cuerpo
	var ragdoll: Ragdoll = activo.ragdoll
	var dentro := interior.esta_dentro(ragdoll)
	# Se para donde quedó el torso, sobre lo primero que haya abajo, mirando hacia donde quedó la cabeza.
	var centro := ragdoll.centro()
	var espacio := ragdoll.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(centro + Vector3.UP * 0.3, centro + Vector3.DOWN * 3.0, 1 | 4)
	var golpe := espacio.intersect_ray(consulta)
	var pies: Vector3 = golpe.position if not golpe.is_empty() else centro
	var frente := ragdoll.cabeza.global_position - ragdoll.torso.global_position if ragdoll.cabeza else Vector3.FORWARD
	frente.y = 0.0
	if frente.length() < 0.05:
		frente = Vector3.FORWARD
	var lugar := Transform3D(Basis.looking_at(frente.normalized(), Vector3.UP), pies + Vector3.UP * 0.05)
	interior.llevar_a(cuerpo, dentro)
	cuerpo.levantar(lugar)
	interior.pasar_camara(ragdoll, cuerpo)
	interior.quitar(ragdoll)
	ragdoll.queue_free()
	activos.erase(activo)
	levantado.emit(cuerpo)


## Levanta de inmediato a todos (por ejemplo, al reiniciar la escena).
func levantar_todos() -> void:
	for activo in activos.duplicate():
		_levantar(activo)
