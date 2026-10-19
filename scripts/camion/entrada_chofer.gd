class_name EntradaChofer
extends Node
## Convierte las acciones del jugador local en ComandosConduccion para el camión.
## Es la única parte del manejo que lee la entrada; la simulación nunca toca Input.

@export var camion: Camion


func _ready() -> void:
	# Corre antes que el camión en cada cuadro de física.
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	if camion == null:
		return
	var c := camion.comandos
	c.acelerar = Input.get_action_strength("acelerar")
	c.frenar = Input.get_action_strength("frenar")
	c.girar = Input.get_axis("girar_izquierda", "girar_derecha")
	c.claxon = Input.is_action_pressed("claxon")
	if Input.is_action_just_pressed("reiniciar_camion"):
		c.reiniciar = true
	if Input.is_action_just_pressed("puerta"):
		c.puerta = true
