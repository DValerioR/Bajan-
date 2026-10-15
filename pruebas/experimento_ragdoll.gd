extends Node
## Experimento (no es prueba automática): suelta un ragdoll en el aire, en el mundo normal, y
## reporta cómo caen sus piezas y si sus articulaciones encontraron las dos piezas.

func _ready() -> void:
	var piso := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(20, 1, 20)
	forma.shape = caja
	forma.position = Vector3(0, -0.5, 0)
	piso.add_child(forma)
	add_child(piso)
	var figura := Personaje.new()
	figura.modelo = "galan"
	add_child(figura)
	await get_tree().physics_frame
	var ragdoll := Ragdoll.desde_figura(figura, Transform3D(Basis(), Vector3(0, 2.0, 0)), 60.0, 70.0, 25.0)
	add_child(ragdoll)
	figura.queue_free()
	ragdoll.soltar(Vector3.ZERO, Vector3(2.0, 0.0, 0.0))
	for hijo in ragdoll.get_children():
		if hijo is Joint3D:
			print("%s: a=%s (%s) b=%s (%s)" % [hijo.name, hijo.node_a, hijo.get_node_or_null(hijo.node_a) != null, hijo.node_b, hijo.get_node_or_null(hijo.node_b) != null])
	for k in 8:
		for _i in 15:
			await get_tree().physics_frame
		var linea := "t=%.2f s:" % ((k + 1) * 0.25)
		for nombre in ragdoll.piezas:
			var pieza: RigidBody3D = ragdoll.piezas[nombre]
			linea += " %s y=%.2f" % [nombre.substr(0, 6), pieza.global_position.y]
		print(linea)
	get_tree().quit()
