extends Node3D
## Herramienta de desarrollo: muestra los 16 personajes procesados en fila, de frente.
## Con "piezas" pinta cada pieza de un color para revisar los cortes; con "pose" dobla las
## articulaciones para ver cómo se mueven. Uso:
##   Godot --path . res://pruebas/vista_personajes.tscn -- <salida.png> [piezas|textura|pose]

const CARPETA := "res://modelos/personajes"
const COLORES := [Color(0.95, 0.85, 0.2), Color(0.9, 0.3, 0.3), Color(0.3, 0.5, 0.95), Color(0.2, 0.75, 0.9), Color(0.35, 0.8, 0.35), Color(0.7, 0.45, 0.9)]


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	var modo: String = argumentos[1] if argumentos.size() > 1 else "piezas"
	var nombres := []
	for archivo in DirAccess.get_files_at(CARPETA):
		if archivo.ends_with(".glb"):
			nombres.append(archivo.get_basename())
	var x := 0.0
	var ancho_fila := 0.0
	var fila := 0
	for nombre in nombres:
		var personaje := Personaje.new()
		personaje.modelo = nombre
		add_child(personaje)
		var ancho: float = personaje.ancho
		if fila == 0 and nombres.find(nombre) >= nombres.size() / 2:
			fila = 1
			ancho_fila = x
			x = 0.0
		x += ancho * 0.5
		personaje.position = Vector3(x, -2.3 * fila, 0)
		personaje.rotation_degrees.y = 180.0
		x += ancho * 0.5 + 0.15
		var etiqueta := Label3D.new()
		etiqueta.text = nombre
		etiqueta.pixel_size = 0.004
		etiqueta.modulate = Color.BLACK
		etiqueta.outline_size = 0
		etiqueta.position = personaje.position + Vector3(0, -0.15, 0.5)
		add_child(etiqueta)
		var k := 0
		for pieza in personaje.get_node("Figura").get_children():
			if modo == "piezas":
				var m := StandardMaterial3D.new()
				m.albedo_color = COLORES[k % COLORES.size()]
				pieza.material_override = m
			elif modo == "pose":
				_posar(pieza)
			k += 1
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	x = maxf(x, ancho_fila)
	camara.size = x + 0.2
	camara.position = Vector3(x * 0.5, -0.15, 6)
	camara.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(camara)
	camara.make_current()
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 25, 0)
	add_child(luz)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color(0.86, 0.88, 0.9)
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	ambiente.environment.ambient_light_energy = 0.7
	add_child(ambiente)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(argumentos[0])
	print("Captura: ", argumentos[0])
	get_tree().quit()


func _posar(pieza: Node3D) -> void:
	match pieza.name:
		"Cabeza":
			pieza.rotation_degrees = Vector3(0, 0, 12)
		"BrazoIzquierdo":
			pieza.rotation_degrees = Vector3(0, 0, -70)
		"BrazoDerecho":
			pieza.rotation_degrees = Vector3(50, 0, 0)
		"PiernaIzquierda":
			pieza.rotation_degrees = Vector3(30, 0, 0)
		"PiernaDerecha":
			pieza.rotation_degrees = Vector3(-25, 0, 0)
