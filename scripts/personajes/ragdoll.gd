class_name Ragdoll
extends Node3D
## Ragdoll de muñeco por piezas (DECISIONES.md, D4 y D34): cada pieza del personaje (cabeza,
## torso, brazos, piernas) es un objeto suelto con su forma, unido al torso con una articulación
## de cono. Se arma en el lugar y la pose del personaje, y lo administra GestorRagdolls.
## Para el interior del camión es una sola entidad con varios cuerpos.

const PROPORCION_MASA := {
	"Cabeza": 0.1, "Torso": 0.4,
	"BrazoIzquierdo": 0.075, "BrazoDerecho": 0.075,
	"PiernaIzquierda": 0.175, "PiernaDerecha": 0.175,
}

var piezas: Dictionary = {}
var torso: ObjetoSuelto
var cabeza: ObjetoSuelto


## Arma el ragdoll a partir de la figura de un personaje. `base` es dónde está el personaje
## (en el espacio donde se va a meter el ragdoll). Hay que agregarlo al árbol y luego `soltar()`.
static func desde_figura(figura: Personaje, base: Transform3D, masa_total: float, columpio: float, giro: float) -> Ragdoll:
	var ragdoll := Ragdoll.new()
	ragdoll.name = "Ragdoll"
	for datos in figura.piezas_con_transformacion():
		var nombre: String = datos[0]
		var malla: MeshInstance3D = datos[1]
		var relativa: Transform3D = datos[2]
		var pieza := ObjetoSuelto.new()
		pieza.name = nombre
		pieza.mass = maxf(1.0, masa_total * PROPORCION_MASA.get(nombre, 0.1))
		pieza.angular_damp = 1.5
		pieza.linear_damp = 0.2
		pieza.transform = base * relativa
		var caja := malla.get_aabb()
		var forma := CollisionShape3D.new()
		var cubo := BoxShape3D.new()
		# Un poco más chica que la pieza: así el muñeco no se traba en cada pilar y cabe por las ventanas.
		cubo.size = (caja.size * 0.65).max(Vector3.ONE * 0.08)
		forma.shape = cubo
		forma.position = caja.get_center()
		pieza.add_child(forma)
		var visual := Node3D.new()
		visual.name = "Visual"
		var copia := MeshInstance3D.new()
		copia.mesh = malla.mesh
		# Si la pieza estaba oculta (la cabeza del jugador en primera persona), sigue oculta.
		copia.visible = malla.visible
		for i in malla.mesh.get_surface_count():
			copia.set_surface_override_material(i, malla.get_active_material(i))
		# La boca como estaba (claves de forma) y los párpados, que cuelgan de la cabeza.
		for b in malla.mesh.get_blend_shape_count():
			copia.set_blend_shape_value(b, malla.get_blend_shape_value(b))
		for hija in malla.get_children():
			if hija is MeshInstance3D:
				copia.add_child(hija.duplicate())
		visual.add_child(copia)
		pieza.add_child(visual)
		ragdoll.add_child(pieza)
		ragdoll.piezas[nombre] = pieza
	ragdoll.torso = ragdoll.piezas.get("Torso")
	ragdoll.cabeza = ragdoll.piezas.get("Cabeza")
	for nombre in ragdoll.piezas:
		if nombre != "Torso":
			ragdoll._unir(ragdoll.piezas[nombre], columpio, giro)
	return ragdoll


func _unir(pieza: ObjetoSuelto, columpio: float, giro: float) -> void:
	var articulacion := ConeTwistJoint3D.new()
	articulacion.name = "Union" + pieza.name
	# El eje X de la articulación es el eje de giro de la pieza: a lo largo del miembro.
	var a_lo_largo := Vector3.UP if pieza.name == "Cabeza" else Vector3.DOWN
	articulacion.transform = Transform3D(_base_desde_x(pieza.basis * a_lo_largo), pieza.position)
	articulacion.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(columpio))
	articulacion.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(giro))
	# La articulación y las piezas son hermanas dentro del ragdoll.
	articulacion.node_a = NodePath("../Torso")
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
