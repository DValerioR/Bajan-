extends Node
## Herramienta de desarrollo: abre la prueba del interior, deja manejar al chofer automático,
## camina un poco y guarda capturas desde el jugador y desde afuera.
## Uso: Godot --path . res://pruebas/captura_interior.tscn -- <carpeta>

const ESCENA := "res://escenas/interior_prueba/interior_prueba.tscn"

var _carpeta: String = "user://capturas"
var _escena: Node


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() > 0:
		_carpeta = argumentos[0]
	DirAccess.make_dir_recursive_absolute(_carpeta)
	_escena = load(ESCENA).instantiate()
	add_child(_escena)
	await get_tree().physics_frame
	_escena.get_node("EntradaJugador").queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var jugador: CuerpoPersonaje = _escena.jugador
	var prefijo := "interior"

	await _esperar(2.5)
	await _capturar(prefijo + "_1_jugador_inicio")
	jugador.comandos.mover = Vector2(0.0, 1.0)
	await _esperar(1.2)
	jugador.comandos.mover = Vector2.ZERO
	jugador.comandos.mirar = Vector2(150.0, 0.0)
	await _esperar(1.0)
	await _capturar(prefijo + "_2_jugador_hacia_el_frente")
	jugador.comandos.sujetarse = true
	await _esperar(4.0)
	await _capturar(prefijo + "_3_jugador_sujeto")

	var camion: Camion = _escena.camion
	var externa := Camera3D.new()
	externa.fov = 55.0
	_escena.add_child(externa)
	externa.make_current()
	var b := camion.global_basis
	externa.global_position = camion.global_position - b.x * 6.0 + Vector3.UP * 2.6 + b.z * 1.5
	externa.look_at(camion.global_position + Vector3.UP * 0.9)
	await _capturar(prefijo + "_4_externa_ventanas")
	get_tree().quit()


func _esperar(segundos: float) -> void:
	for _k in roundi(segundos * 60.0):
		await get_tree().physics_frame


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta := _carpeta.path_join(nombre + ".png")
	get_viewport().get_texture().get_image().save_png(ruta)
	print("Captura: ", ruta)
