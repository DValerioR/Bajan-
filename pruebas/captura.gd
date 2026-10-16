extends Node
## Herramienta de desarrollo: maneja el camión por la calle de prueba y guarda capturas de pantalla
## desde la vista del chofer y desde una cámara externa. No es una prueba automática.
## Uso: Godot --path . res://pruebas/captura.tscn -- <carpeta_de_salida>

const ESCENA := "res://escenas/calle_prueba/calle_prueba.tscn"

var _camion: Camion
var _pista: Calle
var _carpeta: String = "user://capturas"
var _indice: int = 0


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() > 0:
		_carpeta = argumentos[0]
	DirAccess.make_dir_recursive_absolute(_carpeta)
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	escena.get_node("EntradaChofer").queue_free()
	escena.get_node("Hud").visible = true
	_camion = escena.camion
	_pista = escena.pista
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_indice = _pista.indice_en_distancia(5.0)
	_camion.colocar(_pista.transform_en_indice(_indice))

	await _manejar(1.5, 0.0)
	await _capturar("1_chofer_parado")
	await _manejar(5.0, 1.0)
	await _capturar("2_chofer_acelerando")
	await _manejar(3.5, 0.6)
	await _capturar("3_chofer_en_curva")

	var externa := Camera3D.new()
	escena.add_child(externa)
	externa.fov = 60.0
	externa.make_current()
	_mirar_desde(externa, Vector3(-6.0, 3.5, 13.0))
	await _capturar("4_externa_trasera")
	_mirar_desde(externa, Vector3(-11.0, 3.0, -9.0))
	await _capturar("5_externa_frente")
	_mirar_desde(externa, Vector3(-1.0, 1.6, -11.0))
	await _capturar("6_externa_frente_bajo")
	_mirar_desde(externa, Vector3(-25.0, 30.0, 25.0))
	await _capturar("7_aerea")
	get_tree().quit()


func _mirar_desde(camara: Camera3D, desplazamiento: Vector3) -> void:
	var b := _camion.global_basis
	camara.global_position = _camion.global_position + b.x * desplazamiento.x + Vector3.UP * desplazamiento.y + b.z * desplazamiento.z
	camara.look_at(_camion.global_position + Vector3.UP * 0.8)


func _manejar(segundos: float, acelerador: float) -> void:
	for _k in roundi(segundos * 60.0):
		var c := _camion.comandos
		c.limpiar()
		_indice = _pista.indice_cercano(_camion.global_position, _indice)
		var adelante := roundi(8.0 + maxf(_camion.velocidad_adelante, 0.0) * 0.6)
		var objetivo := _pista.puntos[(_indice + adelante) % _pista.puntos.size()] + _pista.derecha(_indice + adelante) * _pista.ancho_carril * 0.5
		var local := _camion.global_transform.affine_inverse() * objetivo
		c.girar = clampf(atan2(local.x, -local.z) * 2.2, -1.0, 1.0)
		c.acelerar = acelerador
		await get_tree().physics_frame


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	var ruta := _carpeta.path_join(nombre + ".png")
	imagen.save_png(ruta)
	print("Captura: ", ruta)
