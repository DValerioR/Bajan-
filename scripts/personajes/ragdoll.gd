class_name Ragdoll
extends Node3D
## Ragdoll del personaje (DECISIONES.md, D4, D34 y D52): cada hueso que mueve la malla (cabeza,
## torso, brazos, antebrazos, piernas, pantorrillas) es un objeto suelto con su caja, unido al de
## arriba con una articulación de cono. Lo que se ve es una copia del esqueleto con su malla, cuyos
## huesos siguen a las cajas: el cuerpo tirado se dobla sin partirse. Se arma en el lugar y la pose
## del personaje, y lo administra GestorRagdolls.
## Para el interior del camión es una sola entidad con varios cuerpos: el marcador "Visual" de
## cada caja pasa a su reflejo, y la copia (en el del torso) toma de ahí la pose.

const PROPORCION_MASA := {
	"Cabeza": 0.1, "Torso": 0.4,
	"BrazoIzquierdo": 0.045, "BrazoDerecho": 0.045, "AntebrazoIzquierdo": 0.03, "AntebrazoDerecho": 0.03,
	"PiernaIzquierda": 0.11, "PiernaDerecha": 0.11, "PantorrillaIzquierda": 0.065, "PantorrillaDerecha": 0.065,
}
## Un poco más chicas que la parte del cuerpo: así el muñeco no se traba en cada pilar y cabe por
## las ventanas.
const ESCALA_CAJA := 0.75

var piezas: Dictionary = {}
var torso: ObjetoSuelto
var cabeza: ObjetoSuelto
## La copia del esqueleto que se ve, y por hueso de la copia el marcador que sigue (los huesos sin
## caja, como la Cadera, van pegados al torso: [-1, reposo relativo al torso]).
var _copia: Skeleton3D
var _seguir: Array = []
var _cabeza_oculta: bool = false


## Arma el ragdoll a partir de la figura de un personaje. `base` es dónde está el personaje
## (en el espacio donde se va a meter el ragdoll). Hay que agregarlo al árbol y luego `soltar()`.
static func desde_figura(figura: Personaje, base: Transform3D, masa_total: float, columpio: float, giro: float) -> Ragdoll:
	var ragdoll := Ragdoll.new()
	ragdoll.name = "Ragdoll"
	# Después del interior del camión, que mueve los reflejos en su _process.
	ragdoll.process_priority = 100
	var marcadores := {}
	for datos in figura.huesos_para_ragdoll():
		var nombre: String = datos[0]
		var pose: Transform3D = base * (datos[1] as Transform3D)
		var caja: AABB = datos[2]
		var escala := pose.basis.get_scale()
		var pieza := ObjetoSuelto.new()
		pieza.name = nombre
		pieza.mass = maxf(1.0, masa_total * PROPORCION_MASA.get(nombre, 0.05))
		pieza.angular_damp = 1.5
		pieza.linear_damp = 0.2
		# Los cuerpos físicos no llevan escala: la escala del hueso va en el marcador.
		pieza.transform = pose.orthonormalized()
		var forma := CollisionShape3D.new()
		var cubo := BoxShape3D.new()
		cubo.size = (caja.size * escala * ESCALA_CAJA).max(Vector3.ONE * 0.08)
		forma.shape = cubo
		forma.position = caja.get_center() * escala
		pieza.add_child(forma)
		var visual := Node3D.new()
		visual.name = "Visual"
		var marcador := Node3D.new()
		marcador.name = "Hueso"
		marcador.transform = Transform3D(Basis.from_scale(escala), Vector3.ZERO)
		visual.add_child(marcador)
		pieza.add_child(visual)
		ragdoll.add_child(pieza)
		ragdoll.piezas[nombre] = pieza
		marcadores[nombre] = marcador
	ragdoll.torso = ragdoll.piezas.get("Torso")
	ragdoll.cabeza = ragdoll.piezas.get("Cabeza")
	if ragdoll.torso == null:
		return ragdoll
	var copia: Array = figura.copia_para_ragdoll()
	ragdoll._copia = copia[0]
	ragdoll._cabeza_oculta = copia[2]
	# Se cuelga del marcador del torso: va donde va el torso, dentro o fuera del camión.
	(marcadores["Torso"] as Node3D).add_child(ragdoll._copia)
	ragdoll._copia.transform = copia[1]
	var esqueleto := ragdoll._copia
	var torso_reposo := esqueleto.get_bone_global_rest(esqueleto.find_bone("Torso"))
	# De padres a hijos: la pose global de cada hueso se calcula sobre la de su padre.
	for i in esqueleto.get_parentless_bones():
		ragdoll._agregar_en_orden(i, marcadores, torso_reposo)
	for nombre in ragdoll.piezas:
		if nombre != "Torso":
			ragdoll._unir(ragdoll.piezas[nombre], ragdoll._pieza_de_arriba(nombre), columpio, giro)
	return ragdoll


func _agregar_en_orden(i: int, marcadores: Dictionary, torso_reposo: Transform3D) -> void:
	var nombre := _copia.get_bone_name(i)
	if marcadores.has(nombre):
		_seguir.append([i, marcadores[nombre]])
	else:
		_seguir.append([i, null, torso_reposo.affine_inverse() * _copia.get_bone_global_rest(i)])
	for hijo in _copia.get_bone_children(i):
		_agregar_en_orden(hijo, marcadores, torso_reposo)


## La caja a la que se une un hueso: la de su padre, o el torso si el padre no tiene caja.
func _pieza_de_arriba(nombre: String) -> String:
	var padre := _copia.get_bone_parent(_copia.find_bone(nombre))
	while padre >= 0:
		var suyo := _copia.get_bone_name(padre)
		if piezas.has(suyo):
			return suyo
		padre = _copia.get_bone_parent(padre)
	return "Torso"


func _process(_delta: float) -> void:
	if _copia == null or not is_instance_valid(_copia):
		return
	var a_copia := _copia.get_global_transform_interpolated().affine_inverse()
	var del_torso := Transform3D()
	for datos in _seguir:
		var i: int = datos[0]
		var pose: Transform3D
		if datos[1] != null:
			pose = a_copia * (datos[1] as Node3D).get_global_transform_interpolated()
		else:
			pose = del_torso * (datos[2] as Transform3D)
		if _copia.get_bone_name(i) == "Torso":
			del_torso = pose
		if _cabeza_oculta and _copia.get_bone_name(i) == "Cabeza":
			pose.basis = pose.basis.scaled_local(Vector3.ONE * 0.001)
		_copia.set_bone_global_pose(i, pose)


func _unir(pieza: ObjetoSuelto, arriba: String, columpio: float, giro: float) -> void:
	var articulacion := ConeTwistJoint3D.new()
	articulacion.name = "Union" + pieza.name
	# El eje X de la articulación es el eje de giro de la pieza: a lo largo del hueso (su eje Y).
	articulacion.transform = Transform3D(_base_desde_x(pieza.basis * Vector3.UP), pieza.position)
	articulacion.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(columpio))
	articulacion.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(giro))
	# La articulación y las piezas son hermanas dentro del ragdoll.
	articulacion.node_a = NodePath("../" + arriba)
	articulacion.node_b = NodePath("../" + pieza.name)
	add_child(articulacion)


static func _base_desde_x(x: Vector3) -> Basis:
	x = x.normalized()
	var auxiliar := Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var z := x.cross(auxiliar).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


## Pone a todas las piezas en movimiento con la misma velocidad (más un empujón).
func soltar(velocidad: Vector3, empujon: Vector3) -> void:
	for pieza in piezas.values():
		pieza.linear_velocity = velocidad + empujon
	if cabeza != null:
		cabeza.linear_velocity += empujon * 0.4
	if torso != null:
		torso.angular_velocity = empujon.cross(Vector3.UP) * -0.6


## Si ya casi no se mueve (para levantarse).
func quieto() -> bool:
	for pieza in piezas.values():
		if pieza.linear_velocity.length() > 0.5 or pieza.angular_velocity.length() > 1.5:
			return false
	return true


# --- Para el interior del camión (entidad de varios cuerpos) -----------------

func cuerpos() -> Array:
	return piezas.values()


func centro() -> Vector3:
	return torso.global_position if torso != null else global_position


func nodo_cabeza() -> Node3D:
	return cabeza if cabeza != null else torso
