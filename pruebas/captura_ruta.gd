extends Node
## Herramienta de desarrollo: abre una ruta generada, deja que el chofer automático la maneje y
## guarda capturas desde una cámara externa que sigue al camión (y una aérea al principio), para
## revisar las zonas, las paradas y la terminal. No es una prueba automática.
## Uso: Godot --path . res://pruebas/captura_ruta.tscn -- <carpeta_de_salida> [semilla]

const ESCENA := "res://escenas/ruta/ruta.tscn"
const Ruta := preload("res://escenas/ruta/ruta.gd")
## Segundos de juego entre capturas y cuántas tomar como máximo.
const CADA := 12.0
const MAXIMO := 14

var _carpeta: String = "user://capturas_ruta"
var _escena: Node
var _camara: Camera3D


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() > 0:
		_carpeta = argumentos[0]
	DirAccess.make_dir_recursive_absolute(_carpeta)
	Juego.en_partida = false
	Ruta.semilla_forzada = int(argumentos[1]) if argumentos.size() > 1 else 11
	_escena = load(ESCENA).instantiate()
	add_child(_escena)
	_escena.get_node("EntradaJugador").queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 3.0
	_camara = Camera3D.new()
	_camara.fov = 60.0
	_camara.far = 800.0
	add_child(_camara)
	_camara.make_current()

	var calle: Calle = _escena.calle
	var caja := AABB(calle.puntos[0], Vector3.ZERO)
	for p in calle.puntos:
		caja = caja.expand(p)
	_camara.global_position = caja.get_center() + Vector3(0.0, maxf(caja.size.x, caja.size.z) * 0.9, caja.size.z * 0.3)
	_camara.look_at(caja.get_center())
	await _capturar("00_aerea")

	for k in MAXIMO:
		var inicio := Time.get_ticks_msec()
		while (Time.get_ticks_msec() - inicio) * Engine.time_scale < CADA * 1000.0 and not _escena.terminada:
			_seguir()
			await get_tree().process_frame
		_seguir()
		await _capturar("%02d_%s" % [k + 1, _zona_actual()])
		if _escena.terminada:
			break
	print("Terminada: ", _escena.terminada)
	get_tree().quit()


func _seguir() -> void:
	var camion: Camion = _escena.camion
	var b := camion.global_basis
	_camara.global_position = camion.global_position - b.z * -14.0 + Vector3.UP * 6.0 + b.x * -4.0
	_camara.look_at(camion.global_position + Vector3.UP * 1.0 - b.z * 6.0)


func _zona_actual() -> String:
	var calle: Calle = _escena.calle
	var distancia := float(calle.indice_cercano(_escena.camion.global_position) * Calle.PASO)
	var zona := "?"
	for z in _escena.descripcion.zonas:
		if distancia >= float(z[0]):
			zona = z[1]
	return zona


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	var ruta := _carpeta.path_join(nombre + ".png")
	imagen.save_png(ruta)
	print("Captura: ", ruta)
