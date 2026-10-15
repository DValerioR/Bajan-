extends Node3D
## Herramienta de desarrollo: muestra un modelo importado de frente y guarda una captura.
## Uso: Godot --path . res://pruebas/vista_modelos.tscn -- <modelo.glb> <salida.png>

func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	var modelo: Node3D = load(argumentos[0]).instantiate()
	add_child(modelo)
	var limites := AABB()
	var primero := true
	for malla in modelo.find_children("*", "MeshInstance3D", true, false):
		var caja: AABB = malla.global_transform * malla.get_aabb()
		limites = caja if primero else limites.merge(caja)
		primero = false
	print("Límites del modelo: ", limites)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = maxf(limites.size.x, limites.size.y) * 1.05
	camara.position = limites.get_center() + Vector3(0, 0, 3)
	add_child(camara)
	camara.make_current()
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-30, -20, 0)
	add_child(luz)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color(0.85, 0.85, 0.85)
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color.WHITE
	ambiente.environment.ambient_light_energy = 0.8
	add_child(ambiente)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(argumentos[1])
	print("Captura: ", argumentos[1])
	get_tree().quit()
