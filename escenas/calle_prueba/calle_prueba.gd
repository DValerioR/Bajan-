extends Node3D
## Escena de la etapa 1: el camión en la calle de prueba.
## Conecta las piezas: entrada → camión → interfaz. La interfaz solo recibe datos.

const ESCENA_MENU := "res://escenas/principal.tscn"

@onready var pista: Calle = $Pista
@onready var camion: Camion = $Camion
@onready var hud: HudConduccion = $Hud


func _ready() -> void:
	camion.colocar(pista.transform_en_indice(pista.indice_en_distancia(5.0)))
	camion.pide_reinicio.connect(_reiniciar_camion)
	camion.telemetria.connect(hud.mostrar_telemetria)
	Config.recargado.connect(hud.avisar.bind("AVISO_CONFIG_RECARGADA"))
	$Camion/Carroceria/CamaraChofer.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reiniciar_camion() -> void:
	var i := pista.indice_cercano(camion.global_position)
	camion.colocar(pista.transform_en_indice(i))


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("salir_al_menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file.call_deferred(ESCENA_MENU)
	elif evento is InputEventMouseButton and evento.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
