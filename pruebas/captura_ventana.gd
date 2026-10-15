extends Node
## Herramienta de desarrollo: llena el camión, avienta a un pasajero de pie hacia la ventana
## izquierda y toma capturas desde afuera para ver qué pasa.
## Uso: Godot --path . res://pruebas/captura_ventana.tscn -- <carpeta> <x> <y> <vx> <vy> [z]

const ESCENA := "res://escenas/interior_prueba/interior_prueba.tscn"


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	var carpeta: String = argumentos[0]
	var desde := Vector2(float(argumentos[1]), float(argumentos[2]))
	var empujon := Vector2(float(argumentos[3]), float(argumentos[4]))
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	escena.get_node("EntradaJugador").queue_free()
	escena.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	escena.pasajeros.llenar(15)
	escena.piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	for _k in 240:
		await get_tree().physics_frame
	var de_pie: CuerpoPersonaje = null
	var z := 0.0
	for p in escena.pasajeros.pasajeros:
		if p.estado == GestorPasajeros.Estado.DE_PIE:
			de_pie = p.cuerpo
			z = p.lugar.punto.z
	if argumentos.size() > 5:
		z = float(argumentos[5])
	var camion: Camion = escena.camion
	var camara := Camera3D.new()
	escena.add_child(camara)
	camara.make_current()
	var lado := signf(empujon.x)
	# Del lado derecho los edificios quedan cerca: la cámara va sobre la banqueta.
	camara.global_position = camion.global_transform * Vector3((7.0 if lado < 0.0 else 3.6) * lado, 1.5, z + (0.0 if lado < 0.0 else 3.0))
	camara.look_at(camion.global_transform * Vector3(lado, 0.5, z))
	de_pie.position = Vector3(desde.x, desde.y, z)
	escena.ragdolls.desplomar(Vector3(empujon.x, empujon.y, 0.0), de_pie)
	for k in 6:
		for _i in 6:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("ventana_%d.png" % k))
	print("Capturas listas")
	get_tree().quit()
